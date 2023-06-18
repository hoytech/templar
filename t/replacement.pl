use strict;

use FindBin qw($RealBin);
use lib "$RealBin/../";
use Data::Dumper;
use Template;

use Parser;



testReplacement('');
testReplacement(' ');
testReplacement('$()', 1);
testReplacement('$(i)', 1);
testReplacement(' $(i)', 1);
testReplacement('$(i) ', 1);
testReplacement(' $(i) ', 1);
testReplacement(' $(i) $(j) ', 2);

testReplacement('bef $(blah) aft', 1);
testReplacement('bef $(blah(asdf())) aft', 1);
testReplacement('bef $(()..blah(asdf()),((()))) aft', 1);
testReplacement('bef $(blah $() lll) aft', 1);
testReplacement('bef $ aft');
testReplacement('bef $$ aft');
testReplacement('bef ($) aft');
testReplacement('bef $( aft');
testReplacement('bef $) aft');
testReplacement('bef $ ( aft');

testReplacement('$!(i) ', 1);

print "ALL OK\n";



sub testReplacement {
    my $t = shift;
    my $expectedReplacements = shift;

    if ($t =~ $Parser::replacementParser) {
        my $parsed = \%/;
        #print Dumper($parsed);
        my ($t2, $numReplacements) = reencodeReplacement($parsed);
        die "replacement: '$t' ne '$t2'" if $t ne $t2;
        die "unexpected numReplacements, $expectedReplacements != $numReplacements" if $expectedReplacements != $numReplacements;
    } else {
        print Dumper(\@!);
        die "ERR in replacement: '$t'\n";
    }
}


sub reencodeReplacement {
    my $p = shift;
    my $o = '';
    my $numReplacements = 0;

    for my $f (@{ $p->{fragment} || []}) {
        $o .= $f->{before};
        if (defined $f->{replacement}) {
            $o .= '$';
            $o .= $f->{replaceType} || '';
            $o .= $f->{replacement}; 
            $numReplacements++;
        }
    }

    return ($o, $numReplacements);
}
