#!perl 

use Test::More tests => 29;
#use Data::Dumper;

BEGIN {
    use_ok( 'Bib::CrossRef' ) || print "Bail out!\n";
}

note("tests without using network ...\n");

my $ref = new_ok("Bib::CrossRef");
is($ref->{html},0);
$ref->sethtml; is($ref->{html},1);

my $r=$ref->{ref};
$r->{doi} = 'http://dx.doi.org/10.1080/002071700411304';
is($ref->doi, 'http://dx.doi.org/10.1080/002071700411304');
$r->{score} = 1;
is($ref->score,1);
$r->{atitle}='Survey of gain-scheduling analysis and design';
is($ref->atitle,'Survey of gain-scheduling analysis and design');
$r->{jtitle}='International Journal of Control';
is($ref->jtitle,'International Journal of Control');
$r->{volume}=1;
is($ref->volume,1);
$r->{issue}=2;
is($ref->issue,2);
$r->{date}='2015';
is($ref->date,'2015');
$r->{genre}='article';
is($ref->genre,'article');
$r->{authcount}=2;
$r->{au1}='D. J. Leith';
$r->{au2}='W. E. Leithead';
is($ref->authcount,2);
is($ref->auth(1),'D. J. Leith');
is($ref->auth(2),'W. E. Leithead');
$r->{spage}='1001';
$r->{epage}='1025';
is($ref->spage,'1001');
is($ref->epage,'1025');
my $out;
ok($out=$ref->print('2'));
my $expected=<<"END";
<tr><td>2</td><td><input type="checkbox" name="2" value="" checked></td><td></td><td contenteditable="true">article</td><td contenteditable="true">2015</td><td contenteditable="true">D. J. Leith, W. E. Leithead, </td><td contenteditable="true">Survey of gain-scheduling analysis and design</td><td contenteditable="true">International Journal of Control</td><td contenteditable="true">1</td><td contenteditable="true">2</td><td contenteditable="true">1001-1025</td><td contenteditable="true"><a href=http://dx.doi.org/10.1080/002071700411304>http://dx.doi.org/10.1080/002071700411304</a></td></tr>
<tr><td colspan=12 style="color:#C0C0C0"></td></tr>
END
is($out,$expected);

note("tests requiring a network connection ...\n");

$ref = new_ok("Bib::CrossRef"); # fresh ref
$ref->set_details("Survey of gain-scheduling analysis and design DJ Leith, WE Leithead International journal of control 73 (11), 1001-1025");
$r = $ref->{ref};
#print Dumper($r);
SKIP: {
  skip "Optional network tests", 9 unless (exists $r->{query});
  is($r->{query},"Survey of gain-scheduling analysis and design DJ Leith, WE Leithead International journal of control 73 (11), 1001-1025");
  is($r->{atitle},'Survey of gain-scheduling analysis and design');
  is($r->{jtitle},'International Journal of Control');
  is($r->{authcount},2);
  is($r->{au1},'D. J. Leith');
  is($r->{doi},'http://dx.doi.org/10.1080/002071700411304');
  is($ref->doi(),'http://dx.doi.org/10.1080/002071700411304');
  ok($out=$ref->print('1'));
  $expected="1. article: 2000, D. J. Leith, W. E. Leithead, 'Survey of gain-scheduling analysis and design'. International Journal of Control, 73(11),pp1001-1025, DOI: http://dx.doi.org/10.1080/002071700411304";
  is($out,$expected);
}

diag( "Testing Bib::CrossRef $Bib::CrossRef::VERSION, Perl $], $^X" );
