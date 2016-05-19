#!/usr/bin/perl



=head1 NAME

news.pl - utility to download zip/xml file and pushes news content to redis database

=head1 DESCRIPTION

news.pl - utility to download zip files, then extracts an xml file from zip file. 
It extracts news content from xml file from 'post' field and pushes news content 
to redis database NEWS_XML.


=head1 AUTHORS

Eusuf Nomun


=cut


use warnings;
use strict;
use LWP::Simple qw(!head);
use HTML::Parse;
use HTML::Element;
use URI::URL;
use XML::Simple;
use Encode;
use Redis::Client;
use Redis::Client::List;

# globals
our $site;
our $url;
our $redis_db;
our $outfile;


# Main()
{
   $site = "http://bitly.com/nuvi-plz";
   $url = "http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/";
   $redis_db = 'NEWS_XML';

   $outfile = "news.out";

   open OUT, ">>$outfile" or die "Unable to open log file: $outfile, $!";

   download_zip();

   close OUT;

}#End of Main()



sub download_zip()
{
   my $content; 
   my $parsed_html;

   $content = get($site) || die "Unable to download webpage $!";
   $parsed_html = HTML::Parse::parse_html($content);

   foreach (@{ $parsed_html->extract_links() })
   {
      my $file= $_->[0];
      if ($file =~ /\.zip/ )
      {
         print OUT "Downloading file... $url/$file\n";
         getstore("$url/$file", $file) || die "Unable to downlod $url/$file, $!";

         print OUT "Extracting xml file from $file\n";
         system( "unzip -o $file -d xml/");
         unlink($file) || die "Unable to delete $file, $!";
      }

      push_to_redis();
   }
}




sub push_to_redis()
{

   my @xml_files = glob("xml/*.xml");

   my $client = Redis::Client->new;
   tie my @list, 'Redis::Client::List', key => "$redis_db", client => $client;

   foreach my $xml_file (@xml_files)
   {
      print OUT "XML file: $xml_file\n";

      my $xml = new XML::Simple;
      my $data = $xml->XMLin($xml_file);

      if (defined $data->{post})
      {
         my $news = encode_utf8($data->{post});

         print OUT "$news\n";

         if ($data->{post} ~~ @list)
         {
            print OUT "Duplicate item: Skipping....\n";
         }
         else
         {
            push @list, $news || warn "Unable to push $news to $redis_db\n";
         }
      }

      unlink("$xml_file") || die "Unable to remove xml file: $xml_file\n";
   }
}

__END__


