#!/usr/bin/perl
use strict;
use warnings;

use Mylib qw(prompt prompt_yn);

my @usbdisk;
my $numberusbdisks = 0;

my @output = `diskutil list | grep _scheme | grep -v grep | tr -d '*' | tr -s ' '`;
chomp(@output); # removes newlines
foreach (@output)
{
  my @chunks = split ' ', $_;
  if ($chunks[3] eq "TB") { $chunks[2]*=1024; }
  if ($chunks[2] < 100) { push @usbdisk, $chunks[4]; }
}
$numberusbdisks = $#usbdisk + 1;

if    ($numberusbdisks == 0) { print "There doesn't seem to be an appropriate disk available\n"; }
elsif ($numberusbdisks == 1) { print "There's one disk available\n"; }
else                      { print "There are " . $numberusbdisks . " disks available\n"; }

print "Disks available are:";
foreach (@usbdisk) { print " " . $_; }
print "\n";

    # $combined_line .= $line; # build a single string with all lines
    # The line above is the same as writing:
    # $combined_line = $combined_line.$line;

# diskutil list
# diskutil unmountDisk /dev/disk3
# sudo dd if="mythbuntu-16.04.1-desktop-amd64.iso" of=/dev/rdisk3 bs=4m status=progress  # 'bs=4M' on macOS
# diskutil eject /dev/disk3

# if (prompt_yn("Do you want to import a list")){
#     my @list = prompt("Give the name of the first list file:\n");
#     while (prompt_yn("Do you want to import another gene list file")){
#         push @list, prompt("Give the name of the next list file:\n");
#     }
#     ...; # do something with @list
# }
# The @list is an array. We can append elements via push.
