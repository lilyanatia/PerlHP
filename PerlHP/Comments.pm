package PerlHP::Comments;
require Exporter;
our @ISA=qw(Exporter);
our @EXPORT=qw(add_comment format_comment);

use strict;

use PerlHP::Utils;

sub add_comment($$$;$$)
{
	my ($name,$link,$comment,$id,$filename)=@_;

	my $commentcode=format_comment($name,$link,$comment);

	$id="comments" unless($id);

	unless($filename)
	{
		my ($package,$callerfilename,$line,$subroutine,$hasargs,$wantarray,$evaltext,
		$is_require,$hints,$bitmask)=caller 0;
		$filename=$callerfilename;
	}

	my $page;
	open FILE,$filename or die "Could not read file";
	$page.=$_ while(<FILE>);
	close FILE;

	$page=~s!(<div [^>]*id=(["'])$id\2[^>]*>)(.*?)(</div>)!$1$3$commentcode\n$4!s; #"

	open FILE,">$filename" or die "Could not write to file";
	print FILE $page;
	close FILE;
}

sub format_comment($$$)
{
	my ($name,$link,$comment)=@_;
	my ($trip,$res);

	($name,$trip)=process_tripcode($name,"!");
	$trip=~s/^!//;

	$link=PerlHP::escape_html($link);
	$link="mailto:$link" if($link and $link!~/^$PerlHP::Utils::protocol_re:/);

	$comment=do_wakabamark(undef,0,$comment);

	my $date=localtime time;

	$res="<blockquote>$comment<p class=\"signature\">";
	$res.="<a href=\"$link\">" if($link);
	$res.="<em>$name</em>";
	$res.=" <small>($trip)</small>" if($trip);
	$res.="</a>" if($link);
	$res.=", $date</p></blockquote>";

	return $res;
}
