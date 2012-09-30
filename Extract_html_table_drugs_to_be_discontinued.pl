#!C:\Perl64\bin\perl

print "Content-type: text/html \n\n";

use strict;
use warnings;

use LWP::UserAgent;
use HTML::Tree;
use Text::CSV_XS;

my $url = 'http://www.fda.gov/Drugs/DrugSafety/DrugShortages/ucm050794.htm';
my $file_out = "E:\\DataOnE\\Drug_Shortage\\Drugs_To_Be_Discontinued.csv";

my $ua = LWP::UserAgent->new;
$ua->timeout(120);

my $request = new HTTP::Request('GET', $url);
my $response = $ua->request($request);
my $content = $response->content();

my $tree = HTML::TreeBuilder->new_from_content($content);
$tree->objectify_text;
my $root = $tree->look_down(
                            '_tag', 'div',
                            'class', 'middle-column'
                            );
my @items = $root->content_list(); 

my @new_table;							
for my $item (@items) {
	my $table = $item if ( $item->tag() eq 'table' );
	
	if ($table) {
		my @rows = $table->look_down(
									 '_tag', 'tr'
									);															
		for my $row (@rows) {
			my @cells = $row->look_down('_tag', 'td');
			my @new_row;
			
			if (@cells) {
			
				my $ncells = scalar(@cells);
				
				if ( $ncells != 3) {
					print "# of cells are not 3! Please check this row. ";
				}
				else {
				
					my @new_row;
					my $ind = 0;
					
					for my $cell (@cells) {
					
						my $text_string = "";
						
						for my $text_node ( $cell->look_down('_tag', '~text') ) {
							my $text = $text_node->attr('text');
							$text_string = $text_string." ".$text;
							$text_string =~ s/(.)/(ord($1) > 127) ? "" : $1/egs;
						}	
						push @new_row, $text_string;
						if ($ind == 0) {
							my ($Updated_Date) = ($text_string =~ m/(\d\d*\/\d\d*\/\d\d+)/);
							my $Company;
							($Company = $text_string) =~ s/(updated)*|(\(*\d\d*\/\d\d*\/\d\d+\s*\w*\-*\)*)//gi;
							push @new_row, $Company, $Updated_Date;
						}
						$ind++;
					}
					push @new_table, \@new_row;
				}
			}
		}
	}		
}
$tree = $tree->delete; 			

#output to CSV
my $csv = Text::CSV_XS->new({ binary => 1}) or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
$csv->eol ("\n");
 open my $fh, ">:encoding(utf8)", "$file_out" or die "$file_out: $!";

 for my $output_row (@new_table) {      
    $csv->print ($fh, $_) for $output_row;
 }   

 close $fh or die "$file_out: $!";






