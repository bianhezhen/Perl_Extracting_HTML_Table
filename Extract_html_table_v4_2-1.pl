#!C:\Perl64\bin\perl

print "Content-type: text/html \n\n";

use strict;
use warnings;

use LWP::UserAgent;
use HTML::Tree;
use Text::CSV_XS;

my $url = 'http://www.fda.gov/Drugs/DrugSafety/DrugShortages/ucm050792.htm';
my $file_out = "E:\\DataOnE\\Drug_Shortage\\Drug_Shortage.csv";

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
my $prev_elem = -1;
my @rowSpans = (1,1,1,1,1,1);
my $drug_name = "";
foreach my $item (@items) {

	#Drug Name
	if ( $item->tag() eq 'p' )  {
		if(my $drug = $item->look_down('_tag', 'b') ) {
			my $text_string = "";
			for my $text_node ( $drug->look_down('_tag', '~text') ) {
				my $text = $text_node->attr('text');
				$text_string = $text_string." ".$text;
			}
		    ($drug_name = $text_string) =~ s/(.)/(ord($1) > 127) ? "" : $1/egs;     
		}   
	}
	
	#HTML Table
    if ( $item->tag() eq 'table' || $item->look_down('_tag', 'table') )  {

		my $table; 
		if ($item->tag() eq 'table') { $table = $item; }
		else { $table = $item->look_down('_tag', 'table'); }
		
		my $if_new_table = 0;
		
		my @rows = $table->look_down(   
                                '_tag', 'tr', 
                                sub { !defined($_[0]->attr('bgColor')) }
                            );
		
		@rowSpans = (1,1,1,1,1,1); 			
		for my $row (@rows) {
			my %new_row;
		
			my @cells = $row->look_down('_tag', 'td');
			my $ncells = scalar(@cells);
			
			if ( $ncells > 0 ) {

				my @new_cells;
				my $ind;
				if ( $ncells == 6 || !($if_new_table) ) {$ind = 0;}
				else {$ind = 1;}
				for my $cell (@cells) {
				
					$rowSpans[$ind] = $cell->attr('rowSpan') if defined $cell->attr('rowSpan');
					++$ind;
					
					my $text_array="";
					for my $text_node ( $cell->look_down('_tag', '~text') ) {
						my $text = $text_node->attr('text');
						$text_array =$text_array." ".$text if $text =~ /\S/;	
					}
					$text_array =~ s/(.)/(ord($1) > 127) ? "" : $1/egs;
					push @new_cells, $text_array;
				}					
				
				# Fixing an error in the html code
				if ( $drug_name =~ m/(Lorazepam Injection)/ && !($if_new_table) && $ncells == 5) {
					push @new_cells, $new_cells[4];
					$new_cells[4] = "";	
					$ncells = 6;
					$rowSpans[5] = $rowSpans[4];
					$rowSpans[4] = 1; 
				}
				if ( $drug_name =~ m/(Lorazepam Injection)/ && $if_new_table == 16) {
					push @new_cells, $new_cells[4];
					for (my $i=5; $i>0; $i--) {
						my $j=$i-1;
						$new_cells[$i] = $new_cells[$j];
						$rowSpans[$i] = $rowSpans[$j];
					}
					$new_cells[0] = "";
					$rowSpans[0] = 1; 
					$ncells = 5;
				}
				
				for (my $i=0; $i < 6; $i++) {
					--$rowSpans[$i];
				}
				
				#Drug Name
				$new_row{Drug_Name} = $drug_name;
				
				if ($ncells == 6) {	
					#Company and Company phone
					( $new_row{Company} = $new_cells[0] ) =~ s/(Customer Service)?\:?(\d+\-\w+\-\w+\-?\w*)?\(?[\d\-]*\)?//g;
					$new_row{Company_phone} = "";
					my @phones = $new_cells[0] =~ m/\(?\d+\)?\-*\d*\-+\w*\-*\w*/g;
					for my $phone (@phones) { 
						$new_row{Company_phone} = $new_row{Company_phone}." ".$phone; 
					}	
			
					#Product and NDC
					( $new_row{Product} = $new_cells[1] ) =~ s/(\(?\s*NDC\s*\)?[\d\-]+\)?\s*)//ig; 
					my @NDCs = $new_cells[1] =~ m/\d+\-+\d+\-+\d+/g;	
					my $length_NDCs = scalar(@NDCs);	
					$new_row{Other_NDCs} = "";
					if ($length_NDCs == 0) {
						$new_row{NDC} = "";
					}
					elsif ($length_NDCs == 1) {
						$new_row{NDC} = $NDCs[0];
					} 					
					else {
						$new_row{NDC} = $NDCs[0];
						for (my $i=1; $i<$length_NDCs; $i++) {	
							$new_row{Other_NDCs} = $new_row{Other_NDCs}." ".$NDCs[$i];
						}
					}
					$new_row{NDC} =~ s/\-+/\-/;
					$new_row{NDC} =~ s/\s*//;
			
					#Rest information
					$new_row{Availability_Information} = $new_cells[2];
					$new_row{Notes} = $new_cells[3];
					$new_row{Reason} = $new_cells[4];
					$new_row{Date_Updated_Info} = $new_cells[5];
					($new_row{Date_Updated} = $new_cells[5]) =~ s/[^\d\/]*//;
				}	
				else {
					my $index = 0;
	print $new_cells[0];				
					#Company and Company phone
					if ($rowSpans[0] >= 0) {
						$new_row{Company} = ${$new_table[$prev_elem]}{Company};
						$new_row{Company_phone} = ${$new_table[$prev_elem]}{Company_phone} if exists ${$new_table[$prev_elem]}{Company_phone};
					}
					else {
						( $new_row{Company} = $new_cells[$index] ) =~ s/(Customer Service)?\:?(\d+\-\w+\-\w+\-?\w*)?\(?[\d\-]*\)?//g;
						$new_row{Company_phone} = "";
						my @phones = $new_cells[$index] =~ m/\(?\d+\)?\-*\d*\-*\w*\-*\w*/g;
						for my $phone (@phones) { 
							$new_row{Company_phone} = $new_row{Company_phone}." ".$phone; 
						}
						++$index;
					}	
					
					#Product and NDC
					if ($rowSpans[1] >= 0) {
						$new_row{Product} = ${$new_table[$prev_elem]}{Product};
						$new_row{NDC} = ${$new_table[$prev_elem]}{NDC} if exists ${$new_table[$prev_elem]}{NDC};
						$new_row{Other_NDCs} = ${$new_table[$prev_elem]}{Other_NDCs} if exists ${$new_table[$prev_elem]}{Other_NDCs};
					}
					else {
						( $new_row{Product} = $new_cells[$index] ) =~ s/(\(?\s*NDC\s*\)?[\d\-]+\)?\s*)//ig; 
						my @NDCs = $new_cells[$index] =~ m/\d+\-+\d+\-+\d+/g;;
						my $length_NDCs = scalar(@NDCs);
						$new_row{Other_NDCs} = "";	
						if ($length_NDCs == 0) {
							$new_row{NDC} = "";
						}
						elsif ($length_NDCs == 1) {
							$new_row{NDC} = $NDCs[0];
						} 					
						else {
							$new_row{NDC} = $NDCs[0];
							for (my $i=1; $i<$length_NDCs; $i++) {	
								$new_row{Other_NDCs} = $new_row{Other_NDCs}." ".$NDCs[$i];
							}
						}
						$new_row{NDC} =~ s/\-+/\-/;
						$new_row{NDC} =~ s/\s*//;
						++$index;
					}
					
					#Rest information
					if ($rowSpans[2] >= 0) {
						$new_row{Availability_Information} = ${$new_table[$prev_elem]}{Availability_Information};
					}
					else {
						$new_row{Availability_Information} = $new_cells[$index];
						++$index;
					}	
					if ($rowSpans[3] >= 0) {
						$new_row{Notes} = ${$new_table[$prev_elem]}{Notes};
					}
					else {
						$new_row{Notes} = $new_cells[$index];
						++$index;
					}	
					if ($rowSpans[4] >= 0) {
						$new_row{Reason} = ${$new_table[$prev_elem]}{Reason};
					}
					else {
						$new_row{Reason} = $new_cells[$index];
						++$index;
					}	
					if ($rowSpans[5] >= 0) {
						$new_row{Date_Updated_Info} = ${$new_table[$prev_elem]}{Date_Updated_Info};
						$new_row{Date_Updated} = ${$new_table[$prev_elem]}{Date_Updated};
					}
					else {
						$new_row{Date_Updated_Info} = $new_cells[$index];
						($new_row{Date_Updated} = $new_cells[$index]) =~ s/[^\d\/]*//;
						++$index;
					}	
				}
				push @new_table, \%new_row;
				++$prev_elem;
			}	
		++$if_new_table;	
		}      
    }   
}

#output to CSV
my $csv = Text::CSV_XS->new({ binary => 1}) or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
#$csv->eol ("\r\n");
$csv->eol ("\n");
 open my $fh, ">:encoding(utf8)", "$file_out" or die "$file_out: $!";

 my @output_headers;
 for my $key ( keys $new_table[0] ) {
    push @output_headers, $key;
 }
 $csv->print ($fh, $_) for \@output_headers;

 for my $href (@new_table) {   
    my @output_row;
    for my $column ( keys %$href ) {
        push @output_row, $href->{$column}; 
    }    	
    if ( !($output_row[0] =~ m/(Notes)/ && $output_row[2] =~ m/(Reason)/ && $output_row[3] =~ m/(Company)/ && $output_row[4] =~ m/(Availability Information)/ && $output_row[6] =~ m/(Products)/) ) 
	{$csv->print ($fh, $_) for \@output_row;}
 }   

 close $fh or die "$file_out: $!";

$tree = $tree->delete; 
