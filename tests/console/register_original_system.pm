# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect
# Summary: Rrgister system and modules of the original system by SUSEConnect
# - Register product using SCC_REGCODE code
# - Register modules and extension
# - Check registering status
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use migration;
use registration;

sub run {
    select_console 'root-console';

    my $scc_addons = get_var 'SCC_ADDONS_ORIGIN', '';
    my $retries = 3;    # number of retries to run SUSEConnect commands
    register_product();
    register_addons_cmd($scc_addons, $retries) if $scc_addons;
    # Check that repos actually work
    assert_script_run("zypper --gpg-auto-import-keys ref", timeout => 180, exitcode => [0, 106]);
    assert_script_run("zypper lr | tee /dev/$serialdev");
    assert_script_run("SUSEConnect --status-text | tee /dev/$serialdev", timeout => 60);
    disable_installation_repos;

}

1;
