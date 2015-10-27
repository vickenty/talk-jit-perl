use strict;
use warnings;
use feature "say";
use Orr;

my $xs = Orr::compile(sub {
    my $x = $_[0];
    $x * $x
});

say $xs->(4);

{
    no warnings;
    $xs;
}
