# SUSE's openjdk fips tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openjdk expect
#
# Summary: FIPS: openjdk
#          Jira feature: SLE-21206
#          FIPS 140-3: make OpenJDK be able to use the NSS certified crypto
#          Run Java SSH / Client http://www.jcraft.com/jsch/
# Tags: poo#112034
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use openjdktest;

sub run {
    my $self = @_;

    select_console 'root-console';
    my $vers_file = "/tmp/java_versions.txt";
    script_output("java -version &> $vers_file; javac -version &>> $vers_file");
    validate_script_output("cat $vers_file", sub { m/openjdk version "11\..*/ });
    validate_script_output("cat $vers_file", sub { m/javac 11\..*/ });
    script_output("rm $vers_file");

    select_console 'x11';

    # Start an xterm
    x11_start_program("xterm");
    # Wait before typing to avoid typos
    wait_still_screen(5);

    my $JSCH_JAR = get_var("JSCH_JAR", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/jsch-0.1.55.jar");
    assert_script_run("wget --quiet --no-check-certificate $JSCH_JAR");
    assert_script_run("chmod 777 jsch-0.1.55.jar");

    my $TEST_JAVA = get_var("TEST_JAVA", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Shell.java");
    assert_script_run("wget --quiet --no-check-certificate $TEST_JAVA");
    assert_script_run("chmod 777 Shell.java");

    run_ssh_test();
}

1;