#!/usr/bin/env perl

use DBI;
use warnings;
use strict;


my $dbname = $ARGV[0];
my $mapfile = $ARGV[1];
my %git = ();

if ( @ARGV != 2) {
    print <<END;
Usage: $0 <tracdb> <mapfile>

 tracdb: The Trac SQLite database
 mapfile: The svn2git map file created by the createSVN2GITmap.sh script
END
    exit(1);
}

# Populate svn->git hash map
open (my $lt, "<", $mapfile) or die("Lookup table cannot be found");

while (<$lt>) {
    chomp ($_);
    if (/\s*([0-9a-z]{40})\s*([0-9]+)\s*/) {
        $git{ $2 } = $1;
    }
}

close($lt);

my $SVN_REF = '\[([0-9]+)\]';

# Updates a DB field by changing all SVN references. For SVN revisions that
# don't exist in the map, the reference is left as is
sub update_field {
    my $field = $_[0];
    if (defined($field)) {
        my @matches = $field =~ /$SVN_REF/g;
        foreach my $svn_id (@matches) {
            my $svn_id = $1;
            $field =~ s/\[$svn_id\]/[$git{$svn_id}]/g if exists($git{$svn_id});
        }
        return $field;
    } else {
        return "";
    }
}

my $db = DBI->connect("dbi:SQLite:$dbname", "", "",
    {RaiseError => 1, AutoCommit => 1}) or die ("Could not connect to $dbname");

my $ticket_change = $db->selectall_arrayref("SELECT ticket,time,field,oldValue,newValue FROM ticket_change");

print "Updating ticket_change table\n";
foreach my $row (@$ticket_change) {
    my ($ticket, $time, $field, $oldValue, $newValue) = @$row;
    $oldValue = update_field($oldValue);
    $newValue = update_field($newValue);
    my $q = qq{UPDATE ticket_change SET oldvalue=?, newvalue=? WHERE ticket="$ticket" AND time="$time" AND field="$field"};
    $db->prepare($q)->execute($oldValue, $newValue) or die DBI::errstr;
}

my $ticket= $db->selectall_arrayref("SELECT id, description FROM ticket");

print "Updating ticket table\n";
foreach my $row (@$ticket) {
    my ($id, $description) = @$row;
    $description=update_field($description);
    my $q = qq{UPDATE ticket SET description=? where ID="$id"};
    $db->prepare($q)->execute($description) or die DBI::errstr;
}
