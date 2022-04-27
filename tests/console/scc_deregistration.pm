# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: Lemon <leli@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration "scc_deregistration";

sub run {
    return unless (get_var('SCC_REGISTER') || get_var('HDD_SCC_REGISTERED'));

    select_console 'root-console';
    if ((check_var('UPGRADE_TARGET_VERSION', '15-SP3')) && (is_sle('15-SP1+'))) {
        # Workaround for bsc#1189543, need register python2 before de-register system
        record_soft_failure 'bsc#1189543 - Stale python2 module blocks de-registration after system migration';
        add_suseconnect_product('sle-module-python2');
    }

    scc_deregistration;
}

1;
