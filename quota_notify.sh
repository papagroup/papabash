#!/usr/bin/perl -w
 
# Author <jps@tntmax.com> (https://www.serveradminblog.com/2010/08/postfix-quota-notification-email-script/)
#
# This script assumes that virtual_mailbox_base in defined
# in postfix's main.cf file. This directory is assumed to contain
# directories which themselves contain your virtual user's maildirs.
# For example:
#
# -----------/
#            |
#            |
#    home/vmail/domains/
#        |          |
#        |          |
#  example.com/  foo.com/
#                   |
#                   |
#           -----------------
#           |       |       |
#           |       |       |
#         user1/   user2/  user3/
#                           |
#                           |
#                        maildirsize
#
 
use strict;
 
my $POSTFIX_CF = "/etc/postfix/main.cf";
my $MAILPROG = "/usr/sbin/sendmail -t";
my $WARNPERCENT = 80;
my @POSTMASTERS = ('postmaster@mydomain.tld');
my $CONAME = 'Company ....';
my $COADDR = 'postmaster@mydomain.tld';
my $SUADDR = 'postmaster@mydomain.tld';
my $MAIL_REPORT = 1;
my $MAIL_WARNING = 1;
 
#get virtual mailbox base from postfix config
open(PCF, "< $POSTFIX_CF") or die $!;
my $mboxBase;
while (<PCF>) {
   next unless /virtual_mailbox_base\s*=\s*(.*)\s*/;
   $mboxBase = $1;
}
close(PCF);
 
#assume one level of subdirectories for domain names
my @domains;
opendir(DIR, $mboxBase) or die $!;
while (defined(my $name = readdir(DIR))) {
   next if $name =~ /^\.\.?$/;        #skip '.' and '..'
   next unless (-d "$mboxBase/$name");
   push(@domains, $name);
}
closedir(DIR);
#iterate through domains for username/maildirsize files
my @users;
chdir($mboxBase);
foreach my $domain (@domains) {
        opendir(DIR, $domain) or die $!;
        while (defined(my $name = readdir(DIR))) {
           next if $name =~ /^\.\.?$/;        #skip '.' and '..'
           next unless (-d "$domain/$name");
      push(@users, {"$name\@$domain" => "$mboxBase/$domain/$name"});
        }
}
closedir(DIR);
 
 
#get user quotas and percent used
my (%lusers, $report);
foreach my $href (@users) {
   foreach my $user (keys %$href) {
      my $quotafile = "$href->{$user}/maildirsize";
      next unless (-f $quotafile);
      open(QF, "< $quotafile") or die $!;
      my ($firstln, $quota, $used);
      while (<QF>) {
         my $line = $_;
              if (! $firstln) {
                 $firstln = 1;
                 die "Error: corrupt quotafile $quotafile"
                    unless ($line =~ /^(\d+)S/);
                 $quota = $1;
            last if (! $quota);
            next;
         }
         die "Error: corrupt quotafile $quotafile"
            unless ($line =~ /\s*(-?\d+)/);
         $used += $1;
      }
      close(QF);
      next if (! $used);
      my $percent = int($used / $quota * 100);
      $lusers{$user} = $percent unless not $percent;
   }
}
 
 
#send a report to the postmasters
if ($MAIL_REPORT) {
   open(MAIL, "| $MAILPROG");
   select(MAIL);
   map {print "To: $_\n"} @POSTMASTERS;
   print "From: $COADDR\n";
   print "Subject: Daily Quota Report.\n";
   print "DAILY QUOTA REPORT:\n\n";
   print "----------------------------------------------\n";
   print "| % USAGE |            ACCOUNT NAME          |\n";
   print "----------------------------------------------\n";
   foreach my $luser ( sort { $lusers{$b} <=> $lusers{$a} } keys %lusers ) {
      printf("|   %3d   | %32s |\n", $lusers{$luser}, $luser);
      print "---------------------------------------------\n";
   }
        print "\n--\n";
        print "$CONAME\n";
        close(MAIL);
}
 
#email a warning to people over quota
if ($MAIL_WARNING) {
        foreach my $luser (keys (%lusers)) {
           next unless $lusers{$luser} >= $WARNPERCENT;       # skip those under quota
           open(MAIL, "| $MAILPROG");
           select(MAIL);
           print "To: $luser\n";
      map {print "BCC: $_\n"} @POSTMASTERS;
           print "From: $SUADDR\n";
           print "Subject: WARNING: Your mailbox is $lusers{$luser}% full.\n";
           print "Reply-to: $SUADDR\n";
           print "Your mailbox: $luser is $lusers{$luser}% full.\n\n";
           print "Please consider deleting e-mail and emptying your trash folder to clear some space.\n\n";
           print "Contact <$SUADDR> for further assistance.\n\n";
           print "Thank You.\n\n";
           print "--\n";
           print "$CONAME\n";
           close(MAIL);
        }
}
