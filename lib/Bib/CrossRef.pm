############################################################
#
#   Bib::CrossRef - Uses crossref to robustly parse bibliometric references.
#
############################################################

package Bib::CrossRef;

use 5.8.8;
use strict;
use warnings;
no warnings 'uninitialized';

require Exporter;
use LWP::UserAgent;
use JSON qw/decode_json/;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use HTML::Entities qw(decode_entities encode_entities);
use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS @ISA);

#use Data::Dumper;

$VERSION = '0.01';
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
sethtml clearhtml set_details print printheader printfooter
doi score date atitle jtitle volume issue genre spage epage authcount auth
);
%EXPORT_TAGS = (all => \@EXPORT_OK);

sub new {
    my $self;
    $self->{html} = 0; # use html for error messages ?
    $self->{ref} = {}; # the reference itself
    bless $self;
    return $self;
}

sub sethtml {
  $_[0]->{html} = 1;
}

sub clearhtml {
  $_[0]->{html} = 0;
}

sub _err {
  my ($self, $str) = @_;
  if ($self->{html}) {
    print "<p style='color:red'>",$str,"</p>";
  } else {
    print $str,"\n";
  }
}

sub doi {
  my $self = shift @_;
  return $self->{ref}->{'doi'};
}

sub score {
  my $self = shift @_;
  return $self->{ref}->{'score'};
}

sub atitle {
  my $self = shift @_;
  return $self->{ref}->{'atitle'};
}

sub jtitle {
  my $self = shift @_;
  return $self->{ref}->{'jtitle'};
}

sub volume {
  my $self = shift @_;
  return $self->{ref}->{'volume'};
}

sub issue {
  my $self = shift @_;
  return $self->{ref}->{'issue'};
}

sub date {
  my $self = shift @_;
  return $self->{ref}->{'date'};
}

sub genre {
  my $self = shift @_;
  return $self->{ref}->{'genre'};
}

sub spage {
  my $self = shift @_;
  return $self->{ref}->{'spage'};
}

sub epage {
  my $self = shift @_;
  return $self->{ref}->{'epage'};
}

sub authcount {
  my $self = shift @_;
  return $self->{ref}->{'authcount'};
}

sub auth {
  my ($self, $num) = @_;
  return $self->{ref}->{'au'.$num};
}

sub set_details {
  # given a raw string, use crossref.org to try to convert into a paper reference and doi
  my ($self, $cites) = @_;
  
  my $cites_clean = $cites;
  # tidy up string, escape nasty characters etc.
  $cites_clean =~ s/\s+/+/g; #$cites_clean = uri_escape_utf8($cites_clean);
  my $req = HTTP::Request->new(GET => 'http://search.crossref.org/dois?q='.$cites_clean);
  my $ua = LWP::UserAgent->new;
  my $res = $ua->request($req);
  if ($res->is_success) {
    # extract json response
    my $json = decode_json($res->decoded_content);
    my $ref={};
    # keep a record of the query string we used
    $ref->{'query'} = $cites;
    # extract doi and matching score
    $ref->{'doi'} = $json->[0]{'doi'};
    $ref->{'score'} = $json->[0]{'score'}; #$json->[0]{'normalizedScore'};
    # and get the rest of the details from the coins encoded payload ...
    if (exists $json->[0]{'coins'}) {
      my $coins = $json->[0]{'coins'};
      my @list = split(';',$coins);
      my $authcount=0;
      foreach my $val (@list) {
        my @pieces = split('=',$val);
        $pieces[0] =~ s/rft\.//;
        if ($pieces[0] =~ m/au$/) {
          $authcount++;
          $pieces[0] = 'au'.$authcount;
        }
        $pieces[1] = uri_unescape($pieces[1]);
        $pieces[1] = decode_entities($pieces[1]); # shouldn't be needed, but some html can creep into titles etc
        $pieces[1] =~ s/\&$//; $pieces[1] =~ s/\s+//g; $pieces[1] =~ s/\+/ /g;
        $pieces[1] =~ s/^\s+//;
        $ref->{$pieces[0]} = $pieces[1];
      }
      $ref->{'authcount'} = $authcount;
      $self->{ref} = $ref;
    }
  } else {
    $self->_err("Problem with search.crossref.org: ".$res->status_line);
  }
}

sub printheader {
  return  '<table><tr style="font-weight:bold"><td></td><td>Use</td><td></td><td>Type</td><td><Year></td><td>Authors</td><td>Title</td><td>Journal</td><td>Volume</td><td>Issue</td><td>Pages</td><td>DOI</td></tr>'."\n";
}

sub printfooter {
  return "</table>\n";
}

sub print {
  # return a reference in human readable form
  my ($self, $id) = @_;
  my $ref = $self->{ref};
  if (!defined $id) {$id='';}
  
  my $out='';
  if ($self->{html}) {
    $out.=sprintf "%s", '<tr>';
    $out.=sprintf "%s",  '<td>'.$id.'</td>';
    if (defined $ref->{'score'} && $ref->{'score'}<1) {
      $out.=sprintf "%s",  '<td><input type="checkbox" name="'.$id.'" value=""></td>';
      $out.=sprintf "%s",  '<td style="color:red">Poor match</td>';
    } else {
      $out.=sprintf "%s",  '<td><input type="checkbox" name="'.$id.'" value="" checked></td><td></td>';
    }
    $out.=sprintf "%s",  '<td contenteditable="true">'.$ref->{'genre'}.'</td><td contenteditable="true">'.$ref->{'date'}.'</td><td contenteditable="true">';
    for (my $j = 1; $j <= $ref->{'authcount'}; $j++) {
      $out.=sprintf "%s",  $ref->{'au'.$j}.', ';
    }
    $out.=sprintf "%s",  '</td><td contenteditable="true">'.$ref->{'atitle'}.'</td><td contenteditable="true">'.encode_entities($ref->{'jtitle'}).'</td>';
    $out.=sprintf "%s",  '<td contenteditable="true">';
    if (defined $ref->{'volume'}) {
      $out.=sprintf "%s",  $ref->{'volume'};
    }
    $out.=sprintf "%s",  '</td><td contenteditable="true">';
    if (defined $ref->{'issue'}) {
      $out.=sprintf "%s",  $ref->{'issue'};
    }
    $out.=sprintf "%s",  '</td><td contenteditable="true">';
    if (defined $ref->{'spage'}) {
      $out.=sprintf "%s",  $ref->{'spage'};
    }
    if (defined $ref->{'epage'}) {
      $out.=sprintf "%s",  '-'.$ref->{'epage'};
    }
    $out.=sprintf "%s",  '</td><td contenteditable="true">';
    if (defined $ref->{'doi'}) {
      $out.=sprintf "%s",  '<a href='.$ref->{'doi'}.'>'.$ref->{'doi'}.'</a>';
    }
    $out.=sprintf "%s",  '</td></tr>'."\n";
    $out.=sprintf "%s",  '<tr><td colspan=12 style="color:#C0C0C0">'.encode_entities($ref->{'query'}).'</td></tr>'."\n";
  } else {
    if (length($id)>0) {$out .= $id.". ";}
    if (exists($ref->{'score'}) && $ref->{'score'}<1) {
      $out.=sprintf "%s",  "Poor match (score=$ref->{'score'}):\n";
      $out.=sprintf "%s",  "$ref->{'query'}\n";
    } else {
      #print "$count. ";
    }
    $out.=sprintf "%s",  "$$ref{'genre'}: $$ref{'date'}, ";
    for (my $j = 1; $j <= $ref->{'authcount'}; $j++) {
      $out.=sprintf "%s",  $ref->{'au'.$j}.', ';
    }
    $out.=sprintf "%s",  "\'$ref->{'atitle'}\'. $ref->{'jtitle'}";
    if (defined $ref->{'volume'}) {
      $out.=sprintf "%s",  ", $ref->{'volume'}";
      if (defined $ref->{'issue'}) {
        $out.=sprintf "%s",  "($ref->{'issue'})";
      }
    }
    if (defined $ref->{'spage'}) {
      $out.=sprintf "%s",  ",pp$ref->{'spage'}";
    }
    if (defined $ref->{'epage'}) {
      $out.=sprintf "%s",  '-'.$ref->{'epage'};
    }
    if (defined $ref->{'doi'}) {
      $out.=sprintf "%s",  ", DOI: $ref->{'doi'}";
    }
  }
  return $out;
}

1;

=pod
 
=head1 NAME
 
Bib::CrossRef - Uses crossref to robustly parse bibliometric references.
 
=head1 SYNOPSIS

 use strict;
 use Bib::CrossRef;

# Create a new object
 my $ref = Bib::CrossRef->new();

# Supply some details, Bib::CrossRef will do its best to use this to derive full citation details e.g. the DOI of a document ...

 $ref->set_details('10.1109/jstsp.2013.2251604');
 
# Show the full citation details, in human readable form

 print $ref->print();

article: 2013, Alessandro Checco, Douglas J. Leith, 'Learning-Based Constraint Satisfaction With Sensing Restrictions'. IEEE Journal of Selected Topics in Signal Processing, 7(5),pp811-820, DOI: http://dx.doi.org/10.1109/jstsp.2013.2251604

# Show the full citation details, in html format

 $ref->sethtml;
 print $ref->printheader;
 print $ref->print;
 print $ref->printfooter;


=head1 EXAMPLES

A valid DOI will always be resolved to a full citation
e.g.

 $ref->set_details('10.1109/jstsp.2013.2251604');
 print $ref->print();
 
article: 2013, Alessandro Checco, Douglas J. Leith, 'Learning-Based Constraint Satisfaction With Sensing Restrictions'. IEEE Journal of Selected Topics in Signal Processing, 7(5),pp811-820, DOI: http://dx.doi.org/10.1109/jstsp.2013.2251604

An attempt will be made to resolve almost any text containing citation info 
e.g. article title only

 $ref->set_details('Learning-Based Constraint Satisfaction With Sensing Restrictions');

e.g. author and journal

$ref->set_details('Alessandro Checco, Douglas J. Leith, IEEE Journal of Selected Topics in Signal Processing, 7(5)');

Please bear in mind that crossref provides a great service for free -- don't abuse it by making excessive queries.  If making many queries, be
sure to rate limit them to a sensible level or you will likely get blocked.

=head1 METHODS
 
=head2 new

 my $ref = Bib::CrossRef->new();

Creates a new Bib::CrossRef object

=head2 set_details

 $ref->set_details($string)

Provides a text string that Bib::CrossRef will try to resolve into a full citation with the help of crossref.org

=head2 doi

 my $info = $ref->doi

Returns a string containg the DOI (digital object identifier) field from a full citation.  If present, this 
should be unique to the document.

=head2 score

 my $info = $ref->score

Returns a matching score from crossref.org.  If less than 1, the text provided to set_details() was likely
insufficient to allow the correct full citation to be obtained.

=head2 genre

 my $info = $ref->genre

Returns the type of publication e.g. jounal paper, conference paper etc

=head2 date

 my $info = $ref->date

Returns the year of publication

=head2 atitle

 my $info = $ref->atitle

Returns the article title

=head2 jtitle

 my $info = $ref->jtitle

Returns the name of the journal (in long form)

=head2 authcount

 my $info = $ref->authcount

Returns the number of authors

=head2 auth

 my $info = $ref->auth($num)

Get the name of author number $num (first author is $ref->auth(1))

=head2 volume

 my $info = $ref->volume

Returns the volume number in which paper appeared

=head2 issue

 my $info = $ref->issue

Returns the issue number in which paper appeared

=head2 spage

 my $info = $ref->spage

Returns the start page

=head2 epage

 my $info = $ref->epage

Returns the end page

=head2 print

 print $ref->printheader;

Prints full citation in human readable form.

=head2 sethtml

 $ref->sethtml

Set output format to be html

=head2 clearhtml

 $ref->clearhtml

Set output format to be plain text

=head2 printheader

 print $ref->printheader;

When html formatting is enabled, prints some html header tags

=head2 printfooter

 print $ref->printfooter;

When html formatting is enabled, prints some html footer tags

=head1 EXPORTS
 
You can export the following functions if you do not want to use the object orientated interface:

sethtml clearhtml set_details print printheader printfooter
doi score date atitle jtitle volume issue genre spage epage authcount auth

The tag C<all> is available to easily export everything:
 
use Bib::CrossRef qw(:all);

=head1 VERSION
 
Ver 0.01
 
=head1 AUTHOR
 
Doug Leith 
    
=head1 BUGS
 
Please report any bugs or feature requests to C<bug-rrd-db at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bib-CrossRef>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.
 
=head1 COPYRIGHT
 
Copyright 2015 D.J.Leith.
 
This program is free software; you can redistribute it and/or modify it under the terms of either: the GNU General Public License as published by the Free Software Foundation; or the Artistic License.
 
See http://dev.perl.org/licenses/ for more information.
 
=cut


__END__
