#!/usr/bin/env perl
# Apply the three post-install patches Amnezia's canonical macOS installer
# applies to darwin.bash. Upstream amneziawg-tools' `make install` does not do
# these — without them the daemon-startup races and silently bails.
#
# Usage:  perl patch-awg-quick.pl <path/to/awg-quick>
#
#   1. `wg <subcmd>` → `awg <subcmd>`   (binary renamed at install time)
#   2. `/var/run/wireguard/` → `/var/run/amneziawg/`   (runtime dir rename)
#   3. Insert `sleep 0.3; chmod 444 "$WG_TUN_NAME_FILE" 2>/dev/null` after the
#      `cmd amneziawg-go utun` line so get_real_interface doesn't check the
#      .name file before the daemon has written it.

use strict;
use warnings;

my $path = $ARGV[0] or die "usage: $0 <awg-quick-path>\n";
open my $in,  '<', $path     or die "open $path: $!\n";
open my $out, '>', "$path.t" or die "open $path.t: $!\n";

my $awg_calls     = 0;
my $amnz_paths    = 0;
my $sleep_inserts = 0;

while (my $line = <$in>) {
    my $n1 = ($line =~ s{\bwg }{awg }g);
    my $n2 = ($line =~ s{/var/run/wireguard/}{/var/run/amneziawg/}g);
    $awg_calls  += $n1 // 0;
    $amnz_paths += $n2 // 0;
    print $out $line;
    if ($line =~ /cmd "?\$\{WG_QUICK_USERSPACE_IMPLEMENTATION:-amneziawg-go\}"? utun/) {
        print $out qq(\tsleep 0.3; chmod 444 "\$WG_TUN_NAME_FILE" 2>/dev/null\n);
        $sleep_inserts++;
    }
}

close $out;
rename "$path.t", $path or die "rename: $!\n";

print STDERR "patch-awg-quick: awg-calls=$awg_calls amneziawg-paths=$amnz_paths sleep=$sleep_inserts\n";

# Assertions — abort the build if any rewrite silently skips.
die "expected >=7 wg→awg rewrites, got $awg_calls\n"    if $awg_calls < 7;
die "expected >=3 wireguard→amneziawg path rewrites, got $amnz_paths\n" if $amnz_paths < 3;
die "expected 1 sleep insertion, got $sleep_inserts\n"   if $sleep_inserts != 1;
