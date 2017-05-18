#!/usr/bin/perl -s

use strict;
use warnings;
use Tk;
use Printer;
use DBI;
use Time::Piece;
use List::Util 'first';
use subs qw/setup_db done clear is_valid create timestamp get_printer/;


#*****	Set SHIP FROM here	*********************
#*****	25 CHAR max or it will spill into SHIP TO
my $sf_name      = "Your Company";
my $sf_address1  = 'Your Address';
my $sf_address2  = 'More Address';
my $sf_csz       = 'City, ST 00000';

#*****	Also set for your system   **************
my $company_code  = '0000000';



#*****	 VARS here	*****************************
our $debug;
my ($st_name, $st_address1, $st_address2, $st_csz);
my ($cartons, $purchase_order, $invoice, $message);
my ($weight,$si_method,$st_san,$conn,$insert_ship_sql);
my ($update_sscc18_sql,$select_sscc18_sql,$match);
my @methods = qw/BestWay Express Ground Parcel LTL FLT/;
my @printers;
my $zebra_printer;
my $db_name = "shipping.db";

#*****	Tk Starts HERE   ************************
$debug and print "Starting program\n";
my $window = MainWindow->new;
my $row = 0;
$window->title("Carton Label");
$window->geometry("650x700+50+50");
my $banner_font = $window->fontCreate("banner",-family=>'verdana',-size=>18,-weight=>"bold");
my $normal_font = $window->fontCreate("normal",-family=>'verdana',-size=>14);
my $button_font = $window->fontCreate("buttonfont",-family=>'courier',-size=>12,-weight=>'bold');
my $tiny_font   = $window->fontCreate("smallest",-family=>'verdana',-size=>8);
my $banner = $window->Label(-text=>"Shipping Carton Label Generator",-pady=>5,-font=>"banner")->pack;

#*****	Top Frame  ******************************
my $tf = $window->Frame()->pack(-expand=>1,-fill=>"both");

#Ship From
$tf->Label(-text=>"Ship From: ")->grid(-row=>$row,-column=>1);
my $sf_name_entry = $tf->Entry(-textvariable=>\$sf_name,-bg=>"white",-width=>20,-justify=>"left",-relief=>'flat')->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");

++$row;
$tf->Label(-text=>"Ship From Address: ")->grid(-row=>$row,-column=>1);
my $sf_address1_entry = $tf->Entry(-textvariable=>\$sf_address1,-bg=>"white",-width=>20,-justify=>"left",-relief=>'flat')->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");

++$row;
$tf->Label(-text=>"Ship From Address: ")->grid(-row=>$row,-column=>1);
my $sf_address2_entry = $tf->Entry(-textvariable=>\$sf_address2,-bg=>"white",-width=>20,-justify=>"left",-relief=>'flat')->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Ship From City State Zip: ")->grid(-row=>$row,-column=>1);
my $sf_csz_entry = $tf->Entry(-textvariable=>\$sf_csz,-bg=>"white",-width=>20,-justify=>"left",-relief=>'flat')->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>" ")->grid(-row=>$row,-column=>0);
++$row;

#Ship To
$tf->Label(-text=>"Ship To: ")->grid(-row=>$row,-column=>1);
my $st_name_entry = $tf->Entry(-textvariable=>\$st_name,-font=>"normal",-bg=>"white",-width=>34,-justify=>"left")->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Ship To Address: ")->grid(-row=>$row,-column=>1);
my $st_address1_entry = $tf->Entry(-textvariable=>\$st_address1,-font=>"normal",-bg=>"white",-width=>34,-justify=>"left")->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Ship To Address: ")->grid(-row=>$row,-column=>1);
my $st_address2_entry = $tf->Entry(-textvariable=>\$st_address2,-font=>"normal",-bg=>"white",-width=>34,-justify=>"left")->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Ship To City State Zip: ")->grid(-row=>$row,-column=>1);
my $st_csz_entry = $tf->Entry(-textvariable=>\$st_csz,-font=>"normal",-bg=>"white",-width=>34,-justify=>"left")->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>"nw");
++$row;
$tf->Label(-text=>" ")->grid(-row=>$row,-column=>0);
++$row;

#Shipment Info
$tf->Label(-text=>"Purchase Order: ")->grid(-row=>$row,-column=>1);
my $purchase_order_entry = $tf->Entry(-textvariable=>\$purchase_order,-font=>"normal",-bg=>"white",-width=>12,-justify=>"left")->grid(-row=>$row,-column=>2,-sticky=>"nw");
$tf->Label(-text=>"Invoice: ")->grid(-row=>$row,-column=>3);
my $invoice_entry = $tf->Entry(-textvariable=>\$invoice,-font=>"normal",-bg=>"white",-width=>12,-justify=>"left")->grid(-row=>$row,-column=>4,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Cartons: ")->grid(-row=>$row,-column=>1);
my $cartons_entry = $tf->Entry(-textvariable=>\$cartons,-font=>"normal",-bg=>"white",-width=>5,-justify=>"center",-validate=>"key", -validatecommand=>\&is_valid)->grid(-row=>$row,-column=>2,-sticky=>"nw");
$tf->Label(-text=>"Wgt (OPT): ")->grid(-row=>$row,-column=>3);
my $weight_entry = $tf->Entry(-textvariable=>\$weight,-font=>"normal",-bg=>"white",-width=>5,-justify=>"center",-validate=>"key", -validatecommand=>\&is_valid)->grid(-row=>$row,-column=>4,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Ship Via: ")->grid(-row=>$row,-column=>1);
my $si_method_entry = $tf->Optionmenu(
 -options => [@methods],
 -variable=> \$si_method)->grid(-row=>$row,-column=>2,-sticky=>"nw");
++$row;
$tf->Label(-text=>"Dest SAN/ZIP: ")->grid(-row=>$row,-column=>1);
my $st_san_entry = $tf->Entry(-textvariable=>\$st_san,-font=>'normal', -bg=>'white',-width=>20,-justify=>'left')->grid(-row=>$row,-column=>2,-columnspan=>3,-sticky=>'nw');
++$row;

#*****	Select/Set printer here   ***************
get_printer;
$tf->Label(-text=>"Printer: ")->grid(-row=>$row,-column=>1,-columnspan=>4);
++$row;
my $default_printer_entry = $tf->Optionmenu (
  -options=>[@printers],
  -variable=>\$zebra_printer)->grid(-row=>$row,-column=>1,-columnspan=>4);

#*****	Bottom Frame  ***************************
my $bf = $window->Frame()->pack(-expand=>1,-fill=>"both");

#Buttons
$bf->Button(-text=>"Create Labels",-command=>\&create,-background=>"green",-activebackground=>"#66FF66",-font=>'buttonfont')->grid(-row=>1,-column=>1);
$bf->Label(-text=>"  ")->grid(-row=>1,-column=>2);
$bf->Button(-text=>"CLEAR",-command=>\&clear,-background=>"#33CC00",-activebackground=>"#66FF66",-font=>'buttonfont')->grid(-row=>1,-column=>3);
$bf->Label(-text=>"  ")->grid(-row=>1,-column=>4);
$bf->Button(-text=>"Exit",-command=>\&done,-background=>"#EE7711",-activebackground=>"#EE8822",-font=>'buttonfont')->grid(-row=>1,-column=>5);

#*****	Status Bar	*****************************
$window->Label(-textvariable=>\$message, -borderwidth=>2, -relief=>'groove')->pack(-fill=>'x',-side=>'bottom');

$st_name_entry->focus();
$cartons_entry->insert(0,'1');
if ($match) {
 $zebra_printer = $match;
 $debug and print "Trying to set default printer to $match\n";
}
$debug and print "Finished drawing screen\n";
setup_db();
$message = "Ready to start!";
MainLoop;

#*****	Create (if missing) database  ************
sub setup_db {
 if (-f $db_name and -W $db_name) {
    $conn = DBI->connect("dbi:SQLite:dbname=$db_name","","",{RaiseError=>1,AutoCommit=>1,ShowErrorStatement=>1});
    $debug and print "Database Found \n";
 }
 else {
    $conn = DBI->connect("dbi:SQLite:dbname=$db_name","","",{RaiseError=>1,AutoCommit=>1,ShowErrorStatement=>1});
    $conn->do("CREATE TABLE detail(id INTEGER PRIMARY KEY,st_name, st_add1, st_add2, st_csz, PO, invoice, cartons, SSCC_start, wgt, ship_via, dest_san, local_date)");
    $conn->do("CREATE TABLE sscc18 (next_sscc)");
    $conn->do("INSERT INTO sscc18 VALUES('1000')");
    $debug and print "Database Created - Table Created - Next SSCC is 1000\n";
 }

 $insert_ship_sql = $conn->prepare("INSERT INTO detail VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
 $update_sscc18_sql = $conn->prepare("UPDATE sscc18 SET next_sscc = ?");
 $select_sscc18_sql = $conn->prepare("SELECT next_sscc FROM sscc18");
 $debug and print "SQL Statement Created\n";
}

#*****	Helper to create MySQL format datestamp *
# YYYY-MM-DD HH:MM:00
sub timestamp() {
  my $time = localtime;
  my $today = $time->ymd . " " . $time->hms;
  $debug and print "Database Time: $today\n";
  return $today;
}

#*****	Clear form  *****************************
sub clear {
  $debug and print "Clearing form at user request\n";
  $st_name = '';
  $st_address1 = '';
  $st_address2 = '';
  $st_csz = '';
  $purchase_order = '';
  $invoice = '';
  $cartons_entry->delete(0,'end');
  $cartons_entry->insert(0,'1');
  $weight_entry->delete(0,'end');
  $si_method = 'LTL';
  $st_san = '';
  $st_name_entry->focus();
  $message = "Form cleared, ready to begin...";
}

#*****	Validate Input   ************************
sub is_valid() {
  # only whole digits
  $_[1] =~ /[\d]/;
}

#*****	Find the printers on the system (zebra!)*
# This code is LINUX only, breaks cross-platform usage
sub get_printer {
  my $results = `lpstat -a`;
  my @lines = split(/\n/,$results);
  foreach my $l (@lines) {
    if ($l =~ /^(.+?)\s/m) {
    push @printers, $1;
    }
  }
  $match = first { /zebra/i } @printers;
  $debug and print "Found possible ZPL printer as '$match'\n";
}

#*****	Make label!   ***************************
sub create {
 # TODO check for data "uninitialized value" error
 $debug and print "Starting to make label\n";
 my $i = 1;
 my $b;
 return unless ($cartons > 0);
 while ($i <= $cartons) {
   $select_sscc18_sql->execute();
   my @barcode = $select_sscc18_sql->fetchrow_array();
   $b = sprintf("%09d",$barcode[0]);
   $debug and print "Using SSCC18 $b\n";
   $update_sscc18_sql->execute($barcode[0]+1);
   my $label = "^XA\n";
   $label .= "^POI\n";

   #Zone A
   #Ship From
   #20 CHAR max (1.25")
   $label .= "^CFO,20\n";
   $label .= "^FO40,50\n";
   $label .= "^FD${sf_name}^FS\n";
   $label .= "^FO40,80\n";
   $label .= "^FD${sf_address1}^FS\n";
   $label .= "^FO40,110\n";
   $label .= "^FD${sf_address2}^FS\n";
   $label .= "^FO40,140\n";
   $label .= "^FD${sf_csz}^FS\n";
   $debug and print " A ";

   #Zone B
   #Ship To
   #34 CHAR max (2.75")
   $label .= "^CF0,30\n";
   $label .= "^FO311,50\n";
   $label .= "^FD${st_name}^FS\n";
   $label .= "^FO311,85\n";
   $label .= "^FD${st_address1}^FS\n";
   $label .= "^FO311,120\n";
   $label .= "^FD${st_address2}^FS\n";
   $label .= "^FO311,155\n";
   $label .= "^FD${st_csz}^FS\n";
   $debug and print " B ";

   #Line
   $label .= "^FO20,210\n";
   $label .= "^GB770,0,4^FS\n";
   $label .= "^FO300,30\n";
   $label .= "^GB0,180,4^FS\n";

   #Zone C
   #Postal (420)
   #(2.5")
   if ($st_san) {
   $label .= "^BY2\n";
   $label .= "^FO80,250\n";
   $label .= "^BCN,100,Y,N,,D\n";
   $label .= "^FD(420) ${st_san}^FS";
   }
   $debug and print " C ";

   #Zone D
   #Carrier/Service
   #(1.5")
   $label .= "^CF0,25\n";
   $label .= "^FO520,240\n";
   $label .= "^FDShip Via: ${si_method}^FS\n";
   $debug and print " D ";

   #Line
   $label .= "^FO20,420\n";
   $label .= "^GB770,0,4^FS\n";
   $label .= "^FO510,210\n";
   $label .= "^GB0,210,4^FS\n";

   #Zone E
   #PO Barcode (400)
   #(4.0")
   $label .= "^BY3\n";
   $label .= "^CF0,35\n";
   $label .= "^FO30,460\n";
   $label .= "^FDPO Number:^FS\n";
   if ($purchase_order) {
   $label .= "^FO250,450\n";
   $label .= "^BCN,100,Y,N,,D\n";
   $label .= "^FD(400) ${purchase_order}^FS";
   }
   $debug and print " E ";

   #Line
   $label .= "^FO20,620\n";
   $label .= "^GB770,0,4^FS\n";

   #Zone F
   #Invoice/Cartons/Weights
   #(4.0")
   $label .= "^FO30,660\n";
   $label .= "^FDInvoice^FS\n";
   $label .= "^FO350,660\n";
   $label .= "^FD${invoice}^FS\n";
   if (($weight) and ($weight >0)) {
    $label .= "^FO30,700\n";
    $label .= "^FDWGT:^FS\n";
    $label .= "^FO350,700\n";
    $label .= "^FD${weight}lbs^FS\n";
   }
   $label .= "^CF0,50\n";
   $label .= "^FO30,750\n";
   $label .= "^FDCarton #:^FS\n";
   $label .= "^FO350,750\n";
   $label .= "^FD${i} of ${cartons}^FS\n";
   $debug and print " F ";

   #Line
   $label .= "^FO20,820\n";
   $label .= "^GB770,0,4^FS\n";

   #Zone G / H not used in compact format

   #Zone I
   #SSCC LP /(00)0\d{7}\d{9}0/ (last 0 will change to checksum)
   #20 DIGIT max (4.0")
   $label .= "^FO380,840\n";
   $label .= "^FDSSCC^FS\n";
   $label .= "^BY4\n";
   $label .= "^FO100,890\n";
   $label .= "^BCN,256,Y,N,,D\n";
   $label .= "^FD(00)0${company_code}${b}0^FS\n";
   $debug and print " I\n";

   $label .= "^XZ\n";

   # Print directly to thermal printer
   # TODO Set a WIN32 Printer for cross-platform support
   my $printer = new Printer ('linux' => "lpr -P $zebra_printer");
   $printer->print($label);
   $debug and print "Sent label $i to the printer\n";
   $message = "Printing label $i";
   ++$i;
   sleep(1);		#NOP to keep printer from overloading?
 }
 $insert_ship_sql->execute($st_name,$st_address1,$st_address2,$st_csz,$purchase_order,$invoice,$cartons,$company_code . $b,$weight,$si_method,$st_san,&timestamp);
 $debug and print "Added shipment to database $db_name\n";
}

sub done {
 $debug and print "Exiting at user request\n";
 exit 0;
}

=pod

=head1 Name

BISG Common Carrier Shipping label (4x6)

=head1 Summary

Create a BISG Common Carrier Shipping Label, sized for a 4x6 thermal label, to be sent to a ZPL thermal printer (ie Zebra ZP450).  This version does not use ZONE G or ZONE H.  However, it should be compiant for most uses.

=head1 Author

Anthony Burbank 2017

=head2 Requires

=over 5

=item *

B<perl-tk> Available from CPAN, but it's much easier to install using a package manager like C<sudo apt-get install perl-tk>.  If using Activestate Perl (on Windows) note that Tkx is installed, but this program requires pure Tk.  It may not be available in your version of Activestate but you may be able to find a working version at L<http://www.bribes.org/perl/ppm>. 

=item * 

B<Printer> from CPAN, used to talk directly to the printer.  It calls 'lpr' -- does everyone have that installed by default?  It's still on my system...  It can also have a WIN32 printer defined (and will flip to the right one depending on what platform it's running) but I haven't set it here.

=item *

B<a Zebra Printer> This label is written in ZPL, the Zebra thermal printer langauge.  If you try to send it to any other kind of printer you'll get interesting results.  The printer should be installed on the local system as a RAW device (or generic).  The program will try to guess the right printer, but may guess wrong.

=item *

B<DBI> and the SQLite dbd -- Install using a package manager C<sudo apt-get install libdbd-sqlite3-perl>

=item *

B<Time::Piece> to set the better version of 'localtime' and get a properly formated date for the database

=item *

B<List::Util 'first'> is used to try and pick the Zebra printer out of the available printers on the (linux) system.

=item *

B<lpstat -a> to find the availabe printers on the system.  THIS BREAKS CROSS-PLATFORM compatiblity!  It should still work on OSX (untested) but is now aimed mostly at Linux boxes.  Supposedly, the B<Printer> module can do this but I looked at the code and it's got hard-coded paths in it that don't work on my system.  So...

=back

=head1 Bugs

The fields on the label are fixed width, so text will either overflow or be chopped off (most prominent in SHIP_FROM Zone A)  Watch your character count!  I put in a SLEEP(1) after each label -- it can probably come out but I was afraid of dumping to much to the spooler at once and losing a label.  Missing fields can cause warnings about uninitialized values, safe to ignore but I should fix those.

=head1 Notes on SSCC

The SSCC barcode in ZONE I is made up of 5 parts.  [1] (00) indicates the barcode is a SSCC.  [2] 0 is for CARTON (change to 1 for PALLET, and there's some others too).  [3] The next 7 digits are the company code as assigned by the UCC/EAN/GS1 group.  Change it to all zeros if you don't have one, I guess.  [4] The next 9 digits are unique.  You'll need to keep track of them so they don't get reused -- although in theory as long as the SHIP TO doesn't get the same SSCC it's OK to repeat them.  [5] The last 0 is a placeholder for the printer to add the checksum:  IT WILL CHANGE ON THE PRINTED LABEL.  Don't freak out, it's supposed to do that.  Barcode format is CODE128 with FNC1 (a GS1 format)

=head1 Notes

Add '-debug' to the command line to see some extra information.  

=head1 TODO

More validation on user input -- never trust the user!  Make this work on WIN32 again?  Anyone.... anyone...

=cut





