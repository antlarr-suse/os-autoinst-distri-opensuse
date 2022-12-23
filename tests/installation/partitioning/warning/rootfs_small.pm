# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify Warning Dialog when root partition has too small
# size.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

my $partitioner;

sub run {
    my $test_data = get_test_suite_data();
    my $disk = $test_data->{disks}[0];
    $partitioner = $testapi::distri->get_expert_partitioner();

    $partitioner->run_expert_partitioner();
    foreach my $partition (@{$disk->{partitions}->{rootfs_small}}) {
        $partitioner->add_partition_on_gpt_disk({
                disk => $disk->{name},
                partition => $partition
        });
    }
    $partitioner->accept_changes();

    assert_matches(qr/$test_data->{warnings}->{rootfs_small}/, $partitioner->get_ok_popup_text(),
        "Warning Dialog for too small root partition did not appear, while it is expected.");
}

sub post_run_hook {
    save_screenshot;
    $partitioner->decline_warning();
    $partitioner->cancel_changes({accept_modified_devices_warning => 1});
}

1;
