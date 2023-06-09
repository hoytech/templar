package Parser;

use strict;
use Exporter;
our @EXPORT = qw($htmlParser $replacementParser);

our $htmlParser;
our $replacementParser;

{
    use Regexp::Grammars;

    $htmlParser = qr{
        ^ <before=text> <[tag]>* %% <[sep=text]> $

        <token: tag>
            (?:
                <verbatimTag=(\< ! [^<>]* \>)>
                |
                \< \s* <vTagName=voidTagName> \s* <attrList> /?+ \s* \>
                |
                \< \s* <oTagName=tagName> \s* <attrList> /?+ \s* \>
                    <tagModifierPre=tagModifier>?
                    <beforeInner=text> <[tag]>* %% <[sep=text]>
                (?: \< \s*+ / \s*+ (?:(?i)<cTagName=\_oTagName>) \s*+ \> | <error: (?{ "Expected closing tag for <$MATCH{oTagName}>" })> )
            )
            <tagModifierPost=tagModifier>?

        <token: tagName>
            [\w-]++

        <token: voidTagName>
            (?i) area | base | br | col | embed | hr | img | input | keygen | link | meta | param | source | track | wbr

        <token: attrList>
            <[attr]>* %% \s*

        <token: attr>
            <name=([\w-_]+)> (?: = <delim=(')> <val=([^']*)> ' | = <delim=(")> <val=([^"]*)> " | )

        <token: text>
            <[fragment]>*

        <token: tagModifier>
            <before=(\s*)> <mod=([?@])> <parenGroup>

        <token: parenGroup>
            \( (?: [^()]* <.parenGroup> )* [^()]* \) | <error: Expected matching paren>




        <token: fragment>
            <before=([^<>\$]*+)> \$ <noescape=(!?)> <replacement=parenGroup> | <before=([^<>\$]*+ \$?)>
    }xs;

    $replacementParser = qr{
        ^ <[fragment]>* $

        <token: fragment>
            <before=([^\$]*+)> \$ <noescape=(!?)> <replacement=parenGroup> | <before=([^\$]*+ \$?)>

        <token: parenGroup>
            \( (?: [^()]* <.parenGroup> )* [^()]* \) | <error: Expected matching paren>
    }xs;
}

1;
