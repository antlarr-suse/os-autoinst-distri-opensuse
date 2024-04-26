# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Execute SUT changes which should be permanent
# - Grant permissions on serial device
# - Add hvc0/hvc1 and hvc1/hvc2 to /etc/securetty
# - Register modules if SCC_ADDONS, MEDIA_UPGRADE and in Regression flavor
# are defined
# - If system is vmware, set resolution to 1024x768 (and write to grub)
# - Stop and disable packagekit
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'consoletest';
use testapi;
use utils;
use zypper;
use version_utils 'is_sle';
use serial_terminal 'prepare_serial_console';
use bootloader_setup qw(change_grub_config grub_mkconfig);
use registration;
use services::registered_addons 'full_registered_check';
use List::MoreUtils 'uniq';
use migration 'modify_kernel_multiversion';
use strict;
use warnings;

sub run {
    my ($self) = @_;

    select_console 'root-console';

    ensure_serialdev_permissions;

    prepare_serial_console;

    if (!check_var('DESKTOP', 'textmode')) {
        # Make sure packagekit is not running, or it will conflict with SUSEConnect.
        quit_packagekit;
        # poo#87850 wait the zypper processes in background to finish and release the lock.
        wait_quit_zypper;
    }

    # Register the modules after media migration, so it can do regession
    if (get_var('MEDIA_UPGRADE') && get_var('DO_REGISTRY')) {
        assert_script_run "SUSEConnect -r " . get_var('SCC_REGCODE') . " --url " . get_var('SCC_URL');
        if (is_sle('15+') && check_var('SLE_PRODUCT', 'sles')) {
            add_suseconnect_product(get_addon_fullname('base'), undef, undef, undef, 300, 1);
            add_suseconnect_product(get_addon_fullname('serverapp'), undef, undef, undef, 300, 1);
        }
        if (is_sle('15+') && check_var('SLE_PRODUCT', 'sled')) {
            add_suseconnect_product(get_addon_fullname('base'), undef, undef, undef, 300, 1);
            add_suseconnect_product(get_addon_fullname('desktop'), undef, undef, undef, 300, 1);
            add_suseconnect_product(get_addon_fullname('we'), undef, undef, "-r " . get_var('SCC_REGCODE_WE'), 300, 1);
        }
        my $myaddons = get_var('SCC_ADDONS', '');
        $myaddons .= "dev,lgm,wsm" if (is_sle('<15', get_var('ORIGIN_SYSTEM_VERSION')) && is_sle('15+'));

        # For hpc, system doesn't include legacy module
        $myaddons =~ s/lgm,?//g if (get_var("SCC_ADDONS", "") =~ /hpcm/);
        $myaddons =~ s/sdk/dev/g;
        if ($myaddons ne '') {
            my @my_addons = grep { defined $_ && $_ } split(/,/, $myaddons);
            my @unique_addons = uniq @my_addons;
            my $addons = join(",", @unique_addons);
            register_addons_cmd($addons);
        }
    }

    # bsc#997263 - VMware screen resolution defaults to 800x600
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        change_grub_config('=.*', '=1024x768x32', 'GFXMODE=');
        change_grub_config('=.*', '=1024x768x32', 'GFXPAYLOAD_LINUX=');
        grub_mkconfig;
    }

    # Save output info to logfile
    if (is_sle && get_required_var('FLAVOR') =~ /Migration/) {
        my $out;
        my $timeout = bmwqemu::scale_timeout(30);
        my $waittime = bmwqemu::scale_timeout(5);
        while (1) {
            $out = script_output("SUSEConnect --status-text", proceed_on_failure => 1);
            last if (($timeout < 0) || ($out !~ /System management is locked by the application with pid/));
            sleep $waittime;
            $timeout -= $waittime;
            diag "SUSEConnect --status-text locked: $out";
        }
        diag "SUSEConnect --status-text: $out";
        if (!get_var('MEDIA_UPGRADE')) {
            services::registered_addons::full_registered_check;
        }
    }

    # enable multiversion for kernel-default based on bsc#1097111, for migration continuous cases only
    if (get_var('FLAVOR', '') =~ /Continuous-Migration/) {
        modify_kernel_multiversion("enable");
    }

    assert_script_run 'rpm -q systemd-coredump || zypper -n in systemd-coredump || true', timeout => 200 if get_var('COLLECT_COREDUMPS');

    script_run("zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP6/SUSE:CA.repo", timeout => 640);
    script_run("zypper ref", timeout => 240);
    script_run("ssl_verify=host zypper in -y ca-certificates-suse", timeout => 240);
    script_run("zypper ar -f --no-gpgcheck https://download.suse.de/ibs/home:/alarrosa:/branches:/SUSE:/SLE-15-SP6:/GA:/openssh-9.7/standard/ openssh_9.7", timeout => 240);
    script_run("zypper ref", timeout => 240);
    script_run("zypper up -r openssh_9.7 --allow-vendor-change -y openssh openssh-server openssh-clients openssh-common", timeout => 240);

    # Let's reboot the system to reset the state and try to get select_console to trigger the issue again
    script_run("systemctl reboot", timeout => 10);
    sleep(300);

    reset_consoles;

    select_console 'root-console';

    ensure_serialdev_permissions;

    prepare_serial_console;

    if (!check_var('DESKTOP', 'textmode')) {
        # Make sure packagekit is not running, or it will conflict with SUSEConnect.
        quit_packagekit;
        # poo#87850 wait the zypper processes in background to finish and release the lock.
        wait_quit_zypper;
    }

    script_run("date");
    script_run("sleep 191", timeout => 220, die_on_timeout => 0);
    script_run("date");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    assert_script_run 'save_y2logs /tmp/system_prepare-y2logs.tar.bz2';
    upload_logs '/tmp/system_prepare-y2logs.tar.bz2';
}

1;
