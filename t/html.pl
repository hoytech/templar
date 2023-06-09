use strict;

use FindBin qw($RealBin);
use lib "$RealBin/../";
use Data::Dumper;
use Template;
#use Carp::Always;

use Parser;



testHtml('');
testHtml('<div></div>');
testHtml(' <div></div>');
testHtml('<div></div> ');
testHtml(' <div></div> ');
testHtml(' <div> </div> ');
testHtml(' <div> <p> </p> </div> ');

# void tags
testHtml(' <div> <br> </div> ');
testHtml(' <div> <br/> </div> ', { eq => ' <div> <br> </div> ', });

testHtml(' <div> <BR> </div> ');
testHtml(' <div> </DIV> ', { eq => ' <div> </div> ', });
testHtml(' <div> <img src="/asf"> </div> ');

# modifiers

testHtml('<ul> <li>A</li> <li>B</li> </ul>');
testHtml('<ul> <li>...</li> @(const auto &r : ctx.recs) </ul>', { tagModifierPost => 1, });
testHtml('<ul> <li> @(const auto &r : ctx.recs) ... </li> </ul>', { tagModifierPre => 1, });

testHtml('<div> <p> ?(ctx.something) ... </p> </div>', { tagModifierPre => 1, });
testHtml('<div> <p> ... </p> ?(ctx.something) </div>', { tagModifierPost => 1, });
testHtml('<div> <p> ?(ctx.something) ... </p> ?(ctx.blah) </div>', { tagModifierPre => 1, tagModifierPost => 1, });
testHtml('<br> ?(ctx.something)', { tagModifierPost => 1, });

# attrs

testHtml(q{<div asf-123="q" omg='123'></div>});
testHtml(q{<div asf="isn't it cool" kmf='i say "yes"'></div>});
testHtml(q{<html>      <div id="hi"></div>   </html>});

testHtml(q{<div checked></div>});

# verbatim tags

testHtml('<!doctype>');
testHtml('<!doctype><html></html>');
testHtml('<!DOCTYPE "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">');
testHtml('before <!-- blah blah --> after');

# replacements

testHtml('<div> b $(hi->a > fun(1)) a </div>');
testHtml('<div> b $(hi->a > fun(1)) mid $(blah()) last </div>');

print "ALL OK\n";



sub testHtml {
    my $t = shift;
    my $opt = shift;

    if ($t =~ $Parser::htmlParser) {
        my $parsed = \%/;
        #print Dumper($parsed);
        my $stats = {};
        my $t2 = reencodeHtml($parsed, $stats);

        $t = $opt->{eq} if defined $opt->{eq};
        die "html: '$t' ne '$t2'" if $t ne $t2;

        for my $k (qw/tagModifierPost/) {
            die "in '$t' : bad $k: $opt->{$k} != $stats->{k}" if $opt->{$k} != $stats->{$k};
        }
    } else {
        print Dumper(\@!);
        die "ERR in html: '$t'\n";
    }
}


sub encodeTag {
    my ($tagName, $attrs) = @_;
    $attrs = ($attrs || {})->{attr} || [];

    my $o = '';
    $o .= "<$tagName";

    for my $attr (@$attrs) {
        if ($attr->{delim}) {
            $o .= " $attr->{name}=$attr->{delim}$attr->{val}$attr->{delim}";
        } else {
            $o .= " $attr->{name}";
        }
    }

    $o .= ">";

    return $o;
}

sub reencodeHtml {
    my $parsed = shift;
    my $stats = shift;
    return '' if !ref $parsed;

    my $o = '';

    $o .= $parsed->{before}->{''} if defined $parsed->{before};

    if (defined $parsed->{oTagName}) {
        $o .= encodeTag($parsed->{oTagName}, $parsed->{attrList})
    } elsif (defined $parsed->{vTagName}) {
        $o .= encodeTag($parsed->{vTagName}, $parsed->{attrList})
    }

    if (defined $parsed->{tagModifierPre}) {
        my $tm = $parsed->{tagModifierPre};
        $o .= "$tm->{before}$tm->{mod}$tm->{parenGroup}";
        $stats->{tagModifierPre}++;
    }

    $o .= $parsed->{beforeInner}->{''} || '';

    for (my $i = 0; $i < @{ $parsed->{tag} || [] }; $i++) {
        $o .= reencodeHtml($parsed->{tag}->[$i], $stats) . $parsed->{sep}->[$i]->{''};
    }

    if (defined $parsed->{verbatimTag}) {
        $o .= $parsed->{verbatimTag};
    } elsif (defined $parsed->{oTagName}) {
        $o .= "</$parsed->{oTagName}>";
    }

    if (defined $parsed->{tagModifierPost}) {
        my $tm = $parsed->{tagModifierPost};
        $o .= "$tm->{before}$tm->{mod}$tm->{parenGroup}";
        $stats->{tagModifierPost}++;
    }

    $o .= '$' . uc($parsed->{replacement}) if defined $parsed->{replacement};

    return $o;
}
