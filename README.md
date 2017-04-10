# BISG-Shipping-Label
Generate a standard industry shipping label (common carrier, not UPS) for ZPL printer

Name

    BISG Common Carrier Shipping label (4x6)

Summary

    Create a BISG Common Carrier Shipping Label, sized for a 4x6 thermal
    label, to be sent to a ZPL thermal printer (ie Zebra ZP450). This
    version does not use ZONE G or ZONE H. However, it should be compiant
    for most uses.

Author

    Anthony Burbank 2017

  Requires
  
    *    perl-tk Available from CPAN, but it's much easier to install using
         a package manager like "sudo apt-get install perl-tk". If using
         Activestate Perl (on Windows) note that Tkx is installed, but this
         program requires pure Tk. It may not be available in your version
         of Activestate but you may be able to find a working version at
         <http://www.bribes.org/perl/ppm>.

    *    Printer from CPAN, used to talk directly to the printer. It calls
         'lpr' -- does everyone have that installed by default? It's still
         on my system... It can also have a WIN32 printer defined (and will
         flip to the right one depending on what platform it's running) but
         I haven't set it here.

    *    a Zebra Printer This label is written in ZPL, the Zebra thermal
         printer langauge. If you try to send it to any other kind of
         printer you'll get interesting results. The printer should be
         installed on the local system as a RAW device (or generic). You
         need to change $zebra_printer variable to match the actual name of
         the printer on your system. Unless I added the part that lets you
         choose a printer...

    *    DBI and the SQLite dbd -- Install using a package manager "sudo
         apt-get install libdbd-sqlite3-perl".

Bugs

    The fields on the label are fixed width, so text will either overflow or
    be chopped off (most prominent in SHIP_FROM Zone A) Watch your character
    count! I put in a SLEEP(1) after each label -- it can probably come out
    but I was afraid of dumping to much to the spooler at once and losing a
    label. Missing fields can cause warnings about uninitialized values,
    safe to ignore but I should fix those.

Notes on SSCC

    The SSCC barcode in ZONE I is made up of 5 parts. [1] (00) indicates the
    barcode is a SSCC. [2] 0 is for CARTON (change to 1 for PALLET, and
    there's some others too). [3] The next 7 digits are the company code as
    assigned by the UCC/EAN/GS1 group. Change it to all zeros if you don't
    have one, I guess. [4] The next 9 digits are unique. You'll need to keep
    track of them so they don't get reused -- although in theory as long as
    the SHIP TO doesn't get the same SSCC it's OK to repeat them. [5] The
    last 0 is a placeholder for the printer to add the checksum: IT WILL
    CHANGE ON THE PRINTED LABEL. Don't freak out, it's supposed to do that.
    Barcode format is CODE128 with FNC1 (a GS1 format)

Notes
    Add '-debug' to the command line to see some extra information.

TODO
    More validation on user input -- never trust the user! Get list of
    printers from system and let user choose one (or guess on /zebra/i)
