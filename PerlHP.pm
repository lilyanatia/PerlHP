# PerlHP SE v9.0.0 <> by WAHa.06x36 <> Public domain code

package PerlHP;

use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

BEGIN {
	package PerlHP::Buffer;
	require Tie::Handle;
	@ISA=qw(Tie::Handle);
	sub TIEHANDLE { my ($class,$buffer)=@_; bless $buffer=>$class; }
	sub WRITE { my ($self,$buf,$len,$offset)=@_; $offset=0 unless $offset; $len=length($buf)-$offset unless $len; $$self.=substr $buf,$offset,$len; }

	package PerlHP;
	$out='';
	tie *STDOUT=>"PerlHP::Buffer",\$out;
	set_message(\&error);

	my $q=new CGI;
	sub upload($){ $q->upload(shift) }
	%_REQUEST=$q->Vars; $_REQUEST{$_}=$q->cookie($_) for $q->cookie();

	@{"main::$_"}=split /\\0/,${"main::$_"}=$_REQUEST{$_} for grep /^[a-z_]\w*$/i,keys %_REQUEST;
}
END {
	{ no warnings "untie"; untie *STDOUT; }
	push @PerlHP::headers,"Content-Type: text/html" unless grep /^Content-Type:/,@PerlHP::headers;
	print join("\n",@PerlHP::headers),"\n\n",$PerlHP::out;
}

if(caller)
{
	eval q{
		use 5.008;
		use Filter::Simple;

		require Exporter;
		@ISA=qw(Exporter);
		@EXPORT=qw(perlhp header cookie escape_html echo readfile upload %_REQUEST);

		FILTER { $_=perlhp($_,1); }
	};
}
else
{
	my $src;
	open FILE,$ARGV[0];
	$src.=$_ while <FILE>;
	close FILE;
	eval perlhp($src);
}
die $@ if $@;

sub perlhp($;$)
{
	$_=shift;
	my $p;
	($p,$_)=/(.*?)(?:use PerlHP;(.*)|)$/s unless shift;

	s{(.*?)(?:<([\%\?])(perl|=|)(\s.*?)?(?:\2>|$)|$)}{
		my ($html,$pre,$code)=($1,$3,$4);
		$html=~s/(['\\])/\\$1/g;
		"print '$html';".(($pre eq '=') and "print ")."$code;"
	}sgei;
	$p.$_;
}

sub error($)
{
	$_=shift;
	s!\b(line [0-9]+)!<strong>$1</strong>!g;
	s!\n!<br>!g;
	$out='<html><head><style type="text/css">h1{background:#eef;font-family:sans-serif;font-size:1.5em;font-weight:bold;border-bottom:2px solid #ccf}.c{border:1px dashed #99f;padding:1em;}</style></head>'.
	"<body><h1>Software error</h1><div class='c'><code>$_</code></div></body></html>";
	@headers=();
}

sub header($) { push @headers,shift }

sub cookie($$;$$$$)
{
	my ($name,$value,$expires,$path,$domain,$secure)=@_;
	my $c="Set-Cookie: ".cookie_enc($name)."=".cookie_enc($value);

	if(defined($expires))
	{
		my @days=qw(Sun Mon Tue Wed Thu Fri Sat);
		my @months=qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
		my ($sec,$min,$hour,$mday,$mon,$year,$wday)=gmtime($expires);
		$c.=sprintf("; expires=%s, %02d-%s-%04d %02d:%02d:%02d GMT",$days[$wday],$mday,$months[$mon],$year+1900,$hour,$min,$sec);
	}

	$c.="; path=$path" if $path;
	$c.="; domain=$domain" if $domain;
	$c.="; secure" if $secure;

	header($c);
}

sub cookie_enc($) { $_=shift; s/([^0-9a-zA-Z])/my $c=ord $1; sprintf($c>255?'%%u%04x':'%%%02x',$c)/sge; $_ }

sub escape_html($)
{
	$_=shift;
	#s/&(?!#[0-9]+;|#x[0-9a-fA-F]+;)/&amp;/g;
	s/&/&amp;/g;
	s/\</&lt;/g; s/\>/&gt;/g; s/"/&quot;/g; s/'/&#39;/g; s/,/&#44;/g;
	$_
}

sub echo(@) { print @_ }

sub readfile($) { open my $f,shift or die $!; flock $f,1; do{local $/; <$f>} }

1;

__END__

=head1 NAME

PerlHP - Turn Perl into PHP, or was it the other way around?

=head1 SYNOPSIS

 #!/usr/bin/perl
 use PerlHP;

 <html><body>
 <%
 print "<h1>HTML output</h1>";
 header("X-Header: Custom headers");
 cookie("name","value",$expires,"/path",".domain.com",$secure);
 $safe_string=escape_html($unsafe_string);
 echo "<h2>PHP-style output</h2>";
 %>
 </body></html>

=head1 DESCRIPTION

This modules implements a source filter for embedding Perl code in HTML in
the style of PHP. It also turns query arguments and cookies into global variables,
and handles headers and cookies.

A PerlHP page starts with a normal Perl hashbang, followed by a C<use PerlHP;>
statement.

 #!/usr/bin/perl
 use PerlHP;

On web server which support this, this can be shortened to a single hashbang.
This upsets some webservers, though, so it's not encouraged.

 #!/usr/bin/perl -MPerlHP

On older Perl versions that do not support source filters (5.6.*), you can instead
use this version, which is not as efficient, but which at least works:

 #!/usr/bin/perl PerlHP.pm

The PerlHP.pm module can be installed in your web server's Perl lib directory,
or kept in the same directory as the script. If your Perl installation doesn't
contain the current directory in its library path, you can help it find the
PerlHP module as follows:

 #!/usr/bin/perl
 use lib '.';
 use PerlHP;

This is followed by HTML markup. Perl code is embedded in a C<< <% %> >>,
C<< <? ?> >>, C<< <%perl %> >> or C<< <?perl ?> >> block. Any functions that
outputs text to C<STDOUT>, such as C<print> will insert its output into the
HTML code where the block is located.

 <% print "<h1>HTML output</h1>" %>

In addtion, PHP-style short tags are supported. These add an implicit C<print>
in front of their contents:

 <%= $variable %>

Query arguments and cookies are made available as global variables. If they are
multi-valued, the different values will be separated by null bytes (C<"\0">).
Arrays of the same names as the scalar variables are also created, and contain
the individual values of multi-valued arguments. If C<use strict;> is on, first
declare these variables with C<our>.

 # Print a single argument given, for instance,
 # as http://.../script.pl?argument=value
 <%
 our $argument;
 print escape_html($argument);
 %>
 
 # Print all the values of a multi-valued argument
 # separated by <br />s.
 # http://.../script.pl?list=1&list=2&list=3
 <%
 our @list;
 foreach (@list) { print escape_html($_)."<br />" }
 %>

The C<escape_html()> function should always be applied to values received from
outside the program before printing them, to guard against HTML insertion and
cross-site scripting attacks. It is also strongly recommended to use C<use strict;>
to guard against potentially dangerous coding errors.

=head1 FUNCTIONS

The PerlHP module provides these functions:

=head2 cookie( $name [, $value [, $expire [, $path [, $domain [, $secure]]]]]  )

Set a HTTP cookie in the browser. C<$name> is the name of the cookie, C<$value>
is the value (which, as is not the case with the CGI.pm module, can be a Unicode
string), $expire is the time in seconds when the cookie expires (passing
C<time()> plus the number of seconds until expiration is what you most likely
want to do), $path is the path for which to apply the cookie (defaults to only 
the directory the script resides in), $domain is the sub-domain the cookie should
apply to (you can not specify another domain than the one the script resides on),
and $secure is a boolean flag specifiying if the cookie should apply to normal
or secure (https://) connections.

Very similar to PHP's C<setcookie()> function.

=head2 echo( $string [,$string2,...] )

Alias for print(), for those who want to look more like PHP.

=head2 escape_html( $string )

Turns several characters that have special meanings in HTML and elsewhere into
HTML entities. This is useful both to properly display strings that may contain
special characters, and also to protect your code against HTML insertion and
cross-site scripting attacks. As a rule of thumb, this function should be
applied to all values that come from outside the script, and are printed
anywhere in the HTML page, either as plain text or tag attributes.

The transformations performed are:

=over 3

=item * C<&> (ampersand) becomes C<&amp;>

=item * C<< < >> (less than) becomes C<&lt;>

=item * C<< > >> (greater than) becomes C<&gt;> 

=item * C<"> (double quote) becomes C<&quot;>.

=item * C<'> (single quote) becomes C<&#39;>

=item * C<,> (comma) becomes C<&#44;>

=back

However, numeric HTML entities are left untouched by the ampersand conversion.

=head2 header( $http_header )

Adds a custom HTTP header to the web server response. The header string should
be in the usual HTTP format, and not contain any newlines or preceeding whitespace.

Unlike PHP, you can call C<header()> anywhere in a PerlHP program.

=head2 perlhp( $code )

Parses some PerlHP code, and returns the corresponding PerlHP code. Mostly
for tricky hacks, and not very useful in normal code.

=head2 readfile( $filename )

Reads the contents of the file specified by $filename, and return them as
a scalar. Returns nothing on failure. Puts a shared lock on the file while reading.
The name is confusingly similar to PHP's C<readfile()> function, which doesn't quite
do the same thing!

=head1 TROUBLESHOOTING, QUIRKS AND INTERNALS

=head2 Perl 5.6.*

Perl 5.6.* does not have Filter::Simple, which PerlHP prefers to use. However,
there is an alternate operating mode that works on older Perls, although it is
not as efficient. Change the hashbang to:

 #!/usr/bin/perl PerlHP.pm

In previous versions, you could omit the C<use PerlHP;> line, but in the current
version this is required even when using this workaround. C<use PerlHP;> marks where
the normal Perl code stops and the PerlHP code begins. You must keep the C<PerlHP.pm>
file in the same directory as your script for this to work.

This is not recommended for newer Perl versions. It is merely provided as
a workaround for sites running on older Perls. Also, including external files with
C<do> or C<require> does not work when using this (see the section about require
and do for more information on this).

=head2 use strict;

Earlier versions of PerlHP did not fully support the use of C<use strict;>.
Current versions, however, do. It is recommended that you do use it for all
PerlHP programs, as this is a good way to avoid some security pitfalls with
the automatic globals. To properly utilize C<use strict;>, declare all of
your own variables with C<my>, and all variables that come from external
sources, such as query variables and cookie variables, with C<our>. C<my>
will undefine the previous value of any variable, guaranteeing that they
stay untouched by external sources.

Alternatively, you can use the PHP-style C<%_REQUEST> hash to access your
external variables.

Also remember that everything after C<use PerlHP;> is PerlHP code. You either
have to put the C<use strict;> statement before this, or inside a code section
later.

 #!/usr/bin/perl
 use strict;
 use PerlHP;

 #!/usr/bin/perl
 use PerlHP;
 <% use strict; %>

=head2 HTML sections

The HTML parts of the page are turned into simple C<print> statements. This means
that you can make blocks that extend between different code blocks.

 <% for(1..10) { %>
 *
 <% } %>

This is perfectly legal code, which will output ten asterisks.

=head2 require and do

Earlier versions of PerlHP did not support the use of C<require> and C<do>
to include other PerlHP files, but this is now fully supported. You can use
this to conditionally include parts of pages, or to include templated
material in pages, such as side bars and footers. Remeber to put a
C<use PerlHP;> at the top of each included file, too!

 <% do "include.pl" %>

This does, however, not work in Perl 5.6.*. You can still include pages by
reading the file manually, running the C<perlhp()> function on it, and
then using C<eval> to execute the results.

 <% eval perlhp(readfile("include.pl")) %>

=head1 COPYRIGHT

No copyright is claimed on any part of this code; it is released into the
Public Domain.

=head1 AUTHORS

!WAHa.06x36 <paracelsus@gmail.com>,
Michael Mathews <micmath@gmail.com>

=cut
