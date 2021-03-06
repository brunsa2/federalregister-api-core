require 'test_helper'

module EntryFullTextTransformationTestHelpers
  # include helper module to do XSLT transformations
  include XmlTransformer
  
  # provide sample bulkdata XML and return the transformed version
  def process(xml)
    @html = transform_xml("<RULE>#{xml}</RULE>", "entries/_full_text.html.xslt")
  end
  
  # include the standard rails view testing support
  include ActionController::Assertions::SelectorAssertions
  # but override it to look at what was defined by the `process` method, rather than what is returned by the normal view layer
  def response_from_page_or_rjs
    HTML::Document.new("<html>#{@html}</html>").root
  end
end

class EntryFullTextTransformationTest < ActiveSupport::TestCase
  include EntryFullTextTransformationTestHelpers
  
  context 'emphasized text' do
    should 'add spaces around it when surrounded by word characters' do
      process <<-XML
        <P>John's<E T="03">ex parte</E>rules</P>
      XML
      assert_select "P", :html => "John's <span class=\"E-03\">ex parte</span> rules"
    end
    
    should 'add a space before it when preceded by a comma or a space' do
      process <<-XML
        <P>or,<E T="03">decision</E>.<E T="03">decision</E></P>
      XML
      assert_select "P", :html => "or, <span class=\"E-03\">decision</span>. <span class=\"E-03\">decision</span>"
    end
    
    should 'add a space before it when preceded by a word character' do
      process <<-XML
        <P>John'S<E T="03">decision</E>.</P>
      XML
      assert_select "P", :html => "John'S <span class=\"E-03\">decision</span>."
    end
    
    should 'not add a space before it when not preceded by a word character' do
      process <<-XML
        <P>John's "<E T="03">decision</E>".</P>
      XML
      assert_select "P", :html => "John's \"<span class=\"E-03\">decision</span>\"."
    end
    
    should 'include a space after it when followed by a word character' do
      process <<-XML
        <P>--<E T="03">text</E>is not a good idea</P>
      XML
      assert_select "P", :html => "--<span class=\"E-03\">text</span> is not a good idea"
    end
    
    should 'not include a space after it when followed by a non-word character' do
      process <<-XML
        <P><E T="03">text</E>--is not a good idea</P>
      XML
      assert_select "P", :html => "<span class=\"E-03\">text</span>--is not a good idea"
    end
  end
  
  context 'table of figures' do 
    setup do
      process <<-XML
        <GPOTABLE COLS="2"><TTITLE>First Figure</TTITLE></GPOTABLE>
        <GPOTABLE COLS="2"><TTITLE>Second Figure</TTITLE></GPOTABLE>
        <GPOTABLE COLS="2"><TTITLE /></GPOTABLE>
        <GPOTABLE COLS="2"></GPOTABLE>
      XML
    end
    
    should "not include tables without a TTITLE" do
      assert_select "#table_of_figures + ul li", 2
    end
  end
  
  context 'headers' do
    should "become h* tags, downgraded two levels" do
      process <<-XML
         <HD SOURCE="HD1">Header 1</HD>
         <HD SOURCE="HD2">Header 2</HD>
         <HD SOURCE="HD3">Header 3</HD>
         <HD SOURCE="HD4">Header 4</HD>
       XML
       assert_select "h3[id]", :text => 'Header 1 &#x2191;'
       assert_select "h4[id]", :text => 'Header 2 &#x2191;'
       assert_select "h5[id]", :text => 'Header 3 &#x2191;'
       assert_select "h6[id]", :text => 'Header 4 &#x2191;'
    end
  end
  
  context "simple gpotable" do
    should "map directly to HTML tables" do
      process <<-XML
        <GPOTABLE COLS="2">
          <BOXHD>
            <CHED H="1">First Name</CHED>
            <CHED H="1">Last Name</CHED>
          </BOXHD>
          <ROW>
            <ENT>John</ENT>
            <ENT>Doe</ENT>
          </ROW>
          <ROW>
            <ENT>Jane</ENT>
            <ENT>Doe</ENT>
          </ROW>
        </GPOTABLE>
      XML
    
      assert_select "table" do
        assert_select "thead tr", 1
        assert_select "thead tr th", 2
        assert_select "tbody tr" do |rows|
          rows.each do |row|
            assert_select row, "td", 2
          end
        end
      end
    end
  end
  
  context "table titles" do
    context "with content" do
      setup do
        process <<-XML
          <GPOTABLE COLS="02">
            <TTITLE>Table name</TTITLE>
          </GPOTABLE>
        XML
      end
    
      should "be added as an H5 before the table" do
        assert_select "h5 + table"
        assert_select "h5", :content => "Table name"
      end
    
      should "have an id" do
        assert_select "h5[id]"
      end
    end
    
    context "without content" do
      setup do
        process <<-XML
          <GPOTABLE COLS="02">
            <TTITLE />
          </GPOTABLE>
        XML
      end
      
      should "not be added" do
        assert_select "h5", 0
      end
    end
  end
  
  context "empty table header" do
    setup do
      process <<-XML
        <GPOTABLE COLS="02">
          <TTITLE>Major Diagnostic Categories (MDCs)</TTITLE>
          <BOXHD>
            <CHED H="1"/>
            <CHED H="1"/>
          </BOXHD>
          <ROW>
            <ENT I="01">1</ENT>
            <ENT>Diseases and Disorders of the Nervous System.</ENT>
          </ROW>
        </GPOTABLE>
      XML
    end
    
    should "have no thead" do
      assert_select "table thead", 0
    end
    
    should "have a tbody" do
      assert_select "table tbody tr", 1
    end
  end
  context "two-level table header" do
    setup do
      process <<-XML
        <GPOTABLE COLS="6">
          <BOXHD>
            <CHED H="1"></CHED>
            <CHED H="1">California</CHED>
            <CHED H="2">Population</CHED>
            <CHED H="2">Area</CHED>
            <CHED H="1">Oregon</CHED>
            <CHED H="2">Population</CHED>
            <CHED H="2">Area<EM>1</EM></CHED>
            <CHED H="1">Total</CHED>
            <CHED H="2">Population</CHED>
          </BOXHD>
        </GPOTABLE>
      XML
    end
    
    should "have two header rows" do
      assert_select "table thead tr", 2
    end
      
    should "have four headers in the first header row" do
      assert_select "table thead tr" do |header_rows|
        assert_select header_rows.first, "th", 4
      end
    end
    
    should "span multiple columns in some cells" do
      assert_select "table thead tr" do |header_rows|
        assert_select header_rows.first, "th:nth-of-type(1)[colspan]", 0
        assert_select header_rows.first, "th:nth-of-type(2)[colspan=2]"
        assert_select header_rows.first, "th:nth-of-type(3)[colspan=2]"
        assert_select header_rows.first, "th:nth-of-type(4)[colspan]", 0
      end
    end
    
    should "span multiple rows in some cells" do
      assert_select "th:nth-of-type(1)[rowspan=2]"
      assert_select "th:nth-of-type(4)[rowspan]", 0
    end
  end
  
  context "three-level table header" do
    setup do
      process <<-XML
        <GPOTABLE COLS="5">
          <BOXHD>
            <CHED H="1">A</CHED>
            <CHED H="1">B</CHED>
            <CHED H="2">BA</CHED>
            <CHED H="2">BB</CHED>
            <CHED H="3">BBA</CHED>
            <CHED H="3">BBB</CHED>
            <CHED H="2">BC</CHED>
            <CHED H="1">C</CHED>
            <CHED H="2">CA</CHED>
            <CHED H="3">CAA</CHED>
            <CHED H="2">CB</CHED>
          </BOXHD>
        </GPOTABLE>
      XML
    end
    
    should "have three header rows" do
      assert_select "table thead tr", 3
    end
      
    should "have three headers in the first header row" do
      assert_select "table thead tr" do |header_rows|
        assert_select header_rows.first, "th", 3
      end
    end
    
    should_eventually "span multiple columns in some cells" do
      assert_select "table thead tr" do |header_rows|
        assert_select header_rows.second, "th:not([colspan])", 2
        assert_select header_rows.second, "th:nth-of-type(3)[colspan=4]"
      end
    end
  end
  
  context "insane table header" do
    setup do
      # /e/E7-23571
      process <<-XML
        <GPOTABLE CDEF="s20,10C,10C,10C,10C" COLS="5" OPTS="L4,i1">
          <TTITLE>
            <E T="04">Table 10.&#x2014;Chronic Risk from Exposure to Cupboard (5.25 g) Strips for 24 hours/day</E>
          </TTITLE>
          <BOXHD>
            <CHED H="1">Study</CHED>
            <CHED H="2">POD Type</CHED>
            <CHED H="3">POD (mg/m<E T="51">3</E>)</CHED>
            <CHED H="4">Home ID</CHED>
            <CHED H="4">CD avg &#xF7; 12</CHED>
            <CHED H="1">Rat 2-Year Inhalation</CHED>
            <CHED H="2">BMDL<E T="52">10</E>
            </CHED>
            <CHED H="3">0.078</CHED>
            <CHED H="4">RBC</CHED>
            <CHED H="3">0.41</CHED>
            <CHED H="4">brain</CHED>
            <CHED H="2">BMDL<E T="52">20</E>
            </CHED>
            <CHED H="3">0.196</CHED>
            <CHED H="4">RBC</CHED>
          </BOXHD>
        </GPOTABLE>
      XML
    end
  end

  context "complex table body" do
    setup do 
      process <<-XML
      <GPOTABLE CDEF="s25,12,12,12" COLS="4" OPTS="L2,i1">
        <BOXHD>
          <CHED H="1"/>
          <CHED H="1">Mango</CHED>
          <CHED H="1">Mangosteen</CHED>
          <CHED H="1">Pineapple</CHED>
        </BOXHD>
        <ROW RUL="s">
          <ENT I="22"/>
          <ENT A="02">1,000 lb</ENT>
        </ROW>
        <ROW>
          <ENT I="01">2000</ENT>
          <ENT>528,868</ENT>
          <ENT>40</ENT>
          <ENT>711,292</ENT>
        </ROW>
        <TNOTE>Note: all figures are approximate.</TNOTE>
        <TNOTE>Source: FAOSTAT data, 2006.</TNOTE>
        <SIGDAT>Lorem ipsum</SIGDAT>
        <TDESC>This is a description</TDESC>
      </GPOTABLE>
      XML
    end
    
    should "respect the a attribute on ENT elements" do
      assert_select "table tbody tr:first-of-type td", 2
      assert_select "table tbody tr:first-of-type td:last-of-type[colspan=3]", 1
      
      assert_select "table tbody tr:nth-of-type(2) td:not([colspan])", 4
    end
    
    context "note rows" do
      should "have a particular class" do
        assert_select "table tfoot tr.TNOTE", 2
        assert_select "table tfoot tr.SIGDAT", 1
        assert_select "table tfoot tr.TDESC", 1
      end
    
      should "span all columns" do
        assert_select "tr.TNOTE td[colspan=4], tr.SIGDAT td[colspan=4], tr.TDESC td[colspan=4]", 4
      end
    end
  end
  
  context "table with empty rows" do
    setup do
      process <<-XML
        <GPOTABLE COLS="4">
          <ROW RUL="s">
            <ENT I="25"/>
            <ENT/>
            <ENT/>
            <ENT/>
            <ENT/>
          </ROW>
          <ROW RUL="s">
            <ENT I="25"></ENT>
          </ROW>
          <ROW>
            <ENT I="01">All hospitals</ENT>
            <ENT>3,517</ENT>
            <ENT>$9,996</ENT>
            <ENT>$10,158</ENT>
            <ENT>1.6</ENT>
          </ROW>
          <ROW RUL="s">
            <ENT I="25"/>
          </ROW>
        </GPOTABLE>
      XML
    end
    
    should "only include rows that have text" do
      assert_select "tbody tr", 1
    end
      
  end
  
  context "table with missing cells" do 
    setup do 
      process <<-XML
      <GPOTABLE CDEF="s25,12,12,12" COLS="4" OPTS="L2,i1">
        <BOXHD>
          <CHED H="1">A</CHED>
          <CHED H="1">B</CHED>
          <CHED H="1">C</CHED>
          <CHED H="1">D</CHED>
        </BOXHD>
        <ROW>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
        </ROW>
        <ROW>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
        </ROW>
        <ROW>
          <ENT>Content</ENT>
          <ENT>Content</ENT>
        </ROW>
        <ROW>
          <ENT>Content</ENT>
        </ROW>
        <ROW>
        </ROW>
      </GPOTABLE>
      XML
    end
    
    should "have 4 content cells in the first row" do
      assert_select 'tbody tr:nth-of-type(1) td:not(.empty)', {:count => 4, :text => "Content"}
      assert_select 'tbody tr:nth-of-type(1) td.empty',       {:count => 0, :text => ""}
    end
    
    should "have 3 content cells and 1 empty cell in the second row" do
      assert_select 'tbody tr:nth-of-type(2) td:not(.empty)', {:count => 3, :text => "Content"}
      assert_select 'tbody tr:nth-of-type(2) td.empty',       {:count => 1, :text => ""}
    end
    
    should "have 2 content cells and 2 empty cells in the third row" do
      assert_select 'tbody tr:nth-of-type(3) td:not(.empty)', {:count => 2, :text => "Content"}
      assert_select 'tbody tr:nth-of-type(3) td.empty',       {:count => 2, :text => ""}
    end
    
    should "have 1 content cell and 3 empty cells in the fourth row" do
      assert_select 'tbody tr:nth-of-type(4) td:not(.empty)', {:count => 1, :text => "Content"}
      assert_select 'tbody tr:nth-of-type(4) td.empty',       {:count => 3, :text => ""}
    end
    
  end
end