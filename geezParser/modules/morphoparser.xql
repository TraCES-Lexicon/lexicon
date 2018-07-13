xquery version "3.1"  encoding "UTF-8";

module namespace morpho="http://betamasaheft.eu/parser/morpho";

(:~ 
 : XQuery endpoint to parse requests for Geez parsing, paradigms and conjugations. 
 : includes html view with form and 
 : XML response for parsing query
 : ONLY DEALS WITH 3 radicals VERBS.
 :
 : all XML data processing is in the http://fidal.parser namespace
 : requires 8 XML files to run, whose locations can be set in the global variables:
 :   - letters.xml which contains a list of letters in the fidal and of transcriptions. it includes a empty order for non realized sixth order
 :   - patterns.xml which contains all possible patterns for verb formation, taken from the tables submitted by VITAGRAZIA PISANI and  MAGDALENA KRZYŻANOWSKA
 :   - lemmas.xml which contains an extraction of the lemmas in the Online Dillmann Lexicon Lingua Aethiopicae
 :   - conjugation.xml which contains all distinctive affixes organized by type, number, person, gender as in the tables provided by  VITAGRAZIA PISANI and  MAGDALENA KRZYŻANOWSKA
 :   - nominalforms.xml which contains all distinctive nominal forms as in the tables provided by  VITAGRAZIA PISANI and  MAGDALENA KRZYŻANOWSKA
 :   - nounssuffixes.xml which contains all distinctive affixes organized by type, number, person, gender as in the tables provided by  VITAGRAZIA PISANI and  MAGDALENA KRZYŻANOWSKA
 :   - pronouns.xml which contains a  list of pronouns
 :   - proclitics.xml which contains a list of proclitic particles
 : 
 : the principle is that each given string is transformed into a structured XML fragment which has all the needed information about each letter in the fidal form investigated.
 : this is firstly mildly transliterated to catch possible desinences, and then transformed into candidate patterns. 
 : each pattern is then tested against the actual patterns and is evaluated to produce a candidate root form. 
 : to each existing pattern only the relevant desincences are associated
 : each candidate match is then checked against Dillmann Lexicon Linguae Aethiopicae and for consistency and returned in a tabular way.
 :
 : for the paradigm and conjugation, the root provided is parsed to a structured fragment which is modified according to the patterns in the conjugation.xml and patterns.xml files to produce all possible forms.
 : 
 : the conjugation.xml file contains also pronominal conjugation forms, which include the full desinence, always inclusive of the entire part which is altered.
 :
 : this work was supported by the TraCES and Beta Masaheft projects
 : https://www.traces.uni-hamburg.de/
 : https://www.betamasaheft.uni-hamburg.de/
 : 
 : @author Pietro Maria Liuzzo
 : @version 0.3 
 : @date 2018-07-13

 :  Geez parser is free software: you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
  : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 : Geez parser is distributed in the hope that it will be useful,
 : but WITHOUT ANY WARRANTY; without even the implied warranty of
 : MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 : GNU General Public License for more details.
 : 
 : You should have received a copy of the GNU General Public License
 : along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace config="http://betamasaheft.eu/parser/config" at "config.xqm";

declare namespace f = "http://fidal.parser";
declare namespace t = "http://www.tei-c.org/ns/1.0";
declare namespace s = "http://www.w3.org/2005/xpath-functions";
declare namespace functx = "http://www.functx.com";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json="http://www.json.org";

declare variable $morpho:collection:='parser';
declare variable $morpho:baseurl := "/morpho";

declare variable $morpho:data := '/db/apps/'||$morpho:collection||'/morpho/';
declare variable $morpho:corpus := collection('/db/apps/'||$morpho:collection||'/traces/');
declare variable $morpho:letters := doc($morpho:data || 'letters.xml');
declare variable $morpho:patterns := doc($morpho:data || 'patterns.xml');
declare variable $morpho:lemmas := doc($morpho:data || 'lemmas.xml');
declare variable $morpho:conjugations := doc($morpho:data || 'conjugation.xml');
declare variable $morpho:nouns := doc($morpho:data || 'nounssuffixes.xml');
declare variable $morpho:nominal := doc($morpho:data || 'nominalforms.xml');
declare variable $morpho:proclitics := doc($morpho:data || 'proclitics.xml');
declare variable $morpho:pronouns := doc($morpho:data || 'pronouns.xml');
declare variable $morpho:laryngeals := $morpho:letters//f:letter[@type='laryngeal']//f:realization[2]/text();
declare variable $morpho:sibilants := $morpho:letters//f:letter[@type='sibilant']//f:realization[2]/text();
declare variable $morpho:dentals := $morpho:letters//f:letter[@type='dental']//f:realization[2]/text();
declare variable $morpho:yod := $morpho:letters//f:letter[@type='yod']//f:realization[2]/text();
declare variable $morpho:waw := $morpho:letters//f:letter[@type='waw']//f:realization[2]/text();
declare variable $morpho:neg := $morpho:letters//f:realization[@type='neg']/text();

(:~
 : Helper function which makes a string into a sequence of characters.
 :)
declare function functx:chars
($arg as xs:string?) as xs:string* {
    
    for $ch in string-to-codepoints($arg)
    return
        codepoints-to-string($ch)
};


(:~
 : Takes a query and a few parameters used to filter the results. Sends the main request to the formulas alterantives building function (morpho:formulas())
 : even if the fidal parameter is not set, it will check if the input string is in Ethiopic and if it is not it will convert it to feed the rest of the functions only Fidal
 : returns the response in XML using the http://fidal.parser namespace
 :)
declare
%rest:GET
%rest:path("/morpho/xml/{$query}")
%rest:query-param("transcriptionType", "{$transcriptionType}", "BM")
%rest:query-param("fidal", "{$fidal}", "true")
%rest:query-param("fuzzy", "{$fuzzy}", "false")
%rest:query-param("NoDil", "{$NoDil}", "false")
%rest:query-param("mismatch", "{$mismatch}", "false")
%output:method("xml")
function morpho:XML($query as xs:string?, $transcriptionType as xs:string*, $fidal as xs:string*, $fuzzy as xs:string*, $mismatch as xs:string*, $NoDil as xs:string*){

let $query := morpho:cleanQ($query, $fidal, $transcriptionType)
return
<allresults>{
for $q in $query[.!='']
order by string-length($q) ascending
let $chars := functx:chars($q)

(:particles:)
let $particles := morpho:particles($q)
(: verbi       :)
(:sends 10 queries, one for each schwerer type and one for the regular
adds also a fuzzy search for eventual 4 or 5 radicals:)
let $verbtypes:= 
<verbtypes xmlns="http://fidal.parser">
{if($fuzzy = 'true') then <type>fuzzy</type> else ()}
<type>regular</type>
{for $position in 1 to 3
for $letter in ('w','y','l')
return 
<type>{$letter||$position}</type>}
</verbtypes>
(:nouns      :)
let $nouns:= morpho:formulas($chars,$q,$transcriptionType,'noun')
(:verbs       :)
let $verbs:= for $type in $verbtypes/f:type/text() return morpho:formulas($chars,$q,$transcriptionType,$type)
 
return
<results>
<query>{$q}</query>
<particles>{$particles}</particles>
<verbs>{$verbs}</verbs>
<nouns>{$nouns}</nouns>
</results>
}</allresults>
};


(:~
: maps the results in the f: namespace to the alpheios xsd schema at https://raw.githubusercontent.com/alpheios-project/xml_ctl_files/master/schemas/trunk/lexicon.xsd
 :)
declare
%rest:GET
%rest:path("/morpho/alpheios/{$query}")
%rest:query-param("transcriptionType", "{$transcriptionType}", "BM")
%rest:query-param("fidal", "{$fidal}", "true")
%rest:query-param("fuzzy", "{$fuzzy}", "false")
%rest:query-param("NoDil", "{$NoDil}", "false")
%rest:query-param("mismatch", "{$mismatch}", "false")
%output:method("xml")
function morpho:ALPHEIOS($query as xs:string?, $transcriptionType as xs:string*, $fidal as xs:string*, $fuzzy as xs:string*, $mismatch as xs:string*, $NoDil as xs:string*){
<words>
<phrase>{util:unescape-uri($query, 'UTF-8')}</phrase>
{
let $query := morpho:cleanQ($query, $fidal, $transcriptionType)
for $q in $query

let $chars := functx:chars($q)


(:verbs       :)
(:sends 10 queries, one for each schwerer type and one for the regular
adds also a fuzzy search for eventual 4 or 5 radicals:)
let $verbtypes:=  <verbtypes xmlns="http://fidal.parser">
                                        {if($fuzzy = 'true') then <type>fuzzy</type> else ()}
                                        <type>regular</type>
                                            {for $position in 1 to 3    for $letter in ('w','y','l')    return <type>{$letter||$position}</type>}
                                    </verbtypes>
let $verbs:= for $type in $verbtypes/f:type/text() return morpho:formulas($chars,$q,$transcriptionType,$type)
let $selection := morpho:selection($verbs, $fuzzy, $NoDil, $mismatch)


(:nouns      :)
let $nouns:= morpho:formulas($chars,$q,$transcriptionType,'noun')
let $selectionN := morpho:selection($nouns, $fuzzy, $NoDil, $mismatch)

let $traces := $morpho:corpus//t:f[.=$q]
let $tracesCount := count($traces)

let $cS :=           count($selection)
let $cV :=           count($verbs//f:*[child::f:match])  
let $cSn :=           count($selectionN)
let $cN :=           count($nouns//f:*[child::f:match])      
return
if(($cSn+$cS + $tracesCount) le 0) 
then  <unknown>unknown</unknown> else 
(if(($cSn+$cS) le 0) then () else 
<word>{
for $form in ($selection, $selectionN)//f:desinence
let $match := $form/ancestor::f:match
let $sol := $form/ancestor::f:solution
return
(<form>{$q}</form>,
<entry>
            <dict>
                <hdwd>{$match//f:mainroots/f:root/text()}</hdwd>
                <src>{string($match/following-sibling::f:link[1]/@href)}</src>
            </dict>
            <infl>
                <term>
                    <stem>{$match//f:pattern/text()}</stem>
                    <suff>{$form/f:affix/text()}</suff>
                </term>
                <pofs>{$sol/f:pos/text()}</pofs>
                <note>{$sol/f:group/text()}</note>
                <note>{$sol/f:type/text()}</note>
                {if(($sol/f:mode/text() = 'nominative') or ($sol/f:mode/text() = 'accusative')) 
                    then <case>{lower-case($sol/f:mode/text())}</case> 
                    else <mood>{lower-case($sol/f:mode/text())}</mood>}
                <gend>{lower-case($form/f:gender/text())}</gend>
                <num>{lower-case($form/f:number/text())}</num>
                <pers>{lower-case($form/f:person/text())}</pers>
            </infl>
        </entry>
        )
        }</word>,
    if(($tracesCount) le 0) then () else <word>{
for $form in $traces[@name='fidäl']
let $graphunit := $form/ancestor::t:fs[@type='graphunit']
return
(<form>{$form/text()}</form>,
for $morpho in $graphunit//t:fs[@type='morpho']
let $lemma := substring-after($morpho/t:f[@name='lex']/text(), '--')
return
<entry>
            <dict>
                <hdwd>{$lemma}</hdwd>
                <src>http://betamasaheft.eu/Dillmann/lemma/{substring-before($morpho/t:f[@name='lex']/text(), '--')}</src>
            </dict>
            <infl>
                <term>
                    <stem>{$lemma}</stem>
                </term>
                <pofs>{lower-case($morpho/t:f[@name='pos']/text())}</pofs>
                <mood>{lower-case($morpho/t:f[@name='tam']/text())}</mood>
                <gend>{lower-case($morpho/t:f[@name='gender']/text())}</gend>
                <case>{lower-case($morpho/t:f[@name='case']/text())}</case>
                <note>{lower-case($morpho/t:f[@name='state']/text())}</note>
               <num>{lower-case($morpho/t:f[@name='number']/text())}</num>
                <pers>{lower-case($form/f:person/text())}</pers>
            </infl>
        </entry>)
        
        }</word>    
        )


}</words>
};


(:~
 : Takes a query which should be a string and a few parameters used to filter the results. Sends the main request to the formulas alterantives building function (morpho:formulas())
 : even if the fidal parameter is not set, it will check if the input string is in Ethiopic and if it is not it will convert it to feed the rest of the functions only Fidal
 : returns the response as an HTML page with a form to perform further searches.
 :)
declare
%rest:GET
%rest:path("/morpho")
%rest:query-param("query", "{$query}", "")
%rest:query-param("transcriptionType", "{$transcriptionType}", "BM")
%rest:query-param("fidal", "{$fidal}", "true")
%rest:query-param("fuzzy", "{$fuzzy}", "false")
%rest:query-param("NoDil", "{$NoDil}", "false")
%rest:query-param("mismatch", "{$mismatch}", "false")
%output:method("html")
function morpho:morphoparser($query as xs:string*, $transcriptionType as xs:string*, $fidal as xs:string*, $fuzzy as xs:string*, $NoDil as xs:string*,$mismatch as xs:string*){
<html>
<meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>  
<head><title>Morphological parsing of {$query}</title>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous"></link>
  
<script
  src="https://code.jquery.com/jquery-3.3.1.min.js"
  integrity="sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8="
  crossorigin="anonymous"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
<script type="application/javascript">$('.alert').alert()</script>
  
</head>

<body>
<div class="col-md-12"><h1>Morphological Parser (alpha)</h1></div>
<div class="col-md-12">
<div class="col-md-3"><div class="col-md-12">{morpho:form()}</div></div>
<div class="col-md-9">{
if($query ='') then () else
let $query := morpho:cleanQ($query, $fidal, $transcriptionType)
for $q in $query[.!='']
order by string-length($q) ascending

let $chars := functx:chars($q)

let $traces := $morpho:corpus//t:f[.=$q]
(:particles:)
let $particles := morpho:particles($q)
(: verbs       :)
(:sends 10 queries, one for each schwerer type and one for the regular
adds also a fuzzy search for eventual 4 or 5 radicals:)
let $verbtypes:= 
<verbtypes xmlns="http://fidal.parser">
{if($fuzzy = 'true') then <type>fuzzy</type> else ()}
<type>regular</type>
{for $position in 1 to 3
for $letter in ('w','y','l')
return 
<type>{$letter||$position}</type>}
</verbtypes>

(:nouns      :)
let $nouns:= morpho:formulas($chars,$q,$transcriptionType,'noun')
(:verbs       :)
let $verbs:= for $type in $verbtypes/f:type/text() return morpho:formulas($chars,$q,$transcriptionType,$type)
let $selection := morpho:selection($verbs, $fuzzy, $NoDil, $mismatch)
let $selectionN := morpho:selection($nouns, $fuzzy, $NoDil, $mismatch)
let $selectionP := morpho:selection($particles, $fuzzy, $NoDil, $mismatch)
let $cS :=           count($selection)
let $cV :=           count($verbs//f:*[child::f:match])  
let $cSn :=           count($selectionN)
let $cN :=           count($nouns//f:*[child::f:match])   
let $cSp :=           count($selectionP)
let $cP :=           count($particles//f:*[child::f:match])    
let $tracesCount := count($traces[@name='fidäl'])
return
<div class="col-md-12"><div class="col-md-9">{
if(($cV+$cN+$cP) lt 1) then (<p class="alert alert-warning">Sorry, no matchings for {$q}</p>) else
(<h2>Morphological parsing of {$q}</h2>,
if($cV lt 1) then () else
(
if (starts-with($q, $morpho:neg)) then <p>{'Negative form starting with ' || $morpho:neg}</p>else (),
<p class="alert alert-dismissible alert-warning">{$cS} possibilities shown parsing as verb.</p>,
morpho:selectionmessage($cS, $cV, $fuzzy, $NoDil, $mismatch),
<table class="table table-responsive">
<thead>
<th>Root</th>
<th>Forms</th>
<th>Link Lexicon</th>
<th>Paradigm</th>
<th>TraCES Corpus</th>
</thead>
<tbody>
{for $verb in $selection
let $MR := $verb//f:mainroots/f:root/text()
return
    <tr>
    <td>{if($verb//f:pattern[@attested='no']) then attribute style {'color:red;'} else ()}{string-join($verb//f:solution/f:*/text(), ' ')} ({$verb//f:pattern/text()})</td>
       <td>{for $desinence in $verb//f:solution/f:forms/f:desinence return
                               (('-'||string-join($desinence/f:*[not(name()='length')]/text(), ' ') || (if($desinence/f:pronouns) then (' with object suffix: ' || string-join($desinence/f:pronouns/f:*[not(name()='length')]/text(), ' ')) else ())),<br/>)
                             }
        </td>
    <td>{for $l  in $verb/f:link return 
                (<a  target="_blank">{$l/@href, $l/text()}</a>,<br/>)}
                </td>
    <td><a target="_blank" 
    href="{$morpho:baseurl}/paradigm?root={$MR}">{$MR}</a>
    </td>
    <td>{for $l  in $verb/f:link 
    let $lex := substring-after($l/@href,'http://betamasaheft.eu/Dillmann/lemma/')
    let $corpusattestationsall := $morpho:corpus//t:f[starts-with(.,$lex)]
    let $corpusattestations := $corpusattestationsall[@name='lex']
    return (<a target="_blank" href="{$morpho:baseurl}/corpus?query={$lex}&amp;type=lemma">{count($corpusattestations)}</a>, <br/>)
    }</td>
    </tr>
    }</tbody></table>)
     ,
     if($cN lt 1) then () else
    (
   <p>{$cSn} possibilities shown parsing as noun.</p>,
morpho:selectionmessage($cSn, $cN, $fuzzy, $NoDil, $mismatch),
    <table class="table table-responsive">
<thead>
<th>Pattern</th>
<th>Forms</th>
<th>Link Lexicon</th>
<th>TraCES Corpus</th>
</thead>
<tbody>
{for $noun in $selectionN
return 
<tr>
<td>{$noun//f:pattern/text()}</td>
<td>{for $desinence in $noun//f:solution/f:forms/f:desinence return
                              (('-'||string-join($desinence/f:*[not(name()='length')]/text(), ' ')),<br/>)
                              }</td>
<td>{for $l  in $noun/f:link return 
                (<a  target="_blank">{$l/@href, $l/text()}</a>,<br/>)}</td>
                <td>{for $l  in $noun/f:link 
    let $lex := substring-after($l/@href,'http://betamasaheft.eu/Dillmann/lemma/')
    let $corpusattestations := $morpho:corpus//t:f[@name='lex'][starts-with(.,$lex)]
    return (<a target="_blank" href="{$morpho:baseurl}/corpus?query={$lex}&amp;type=lemma">{count($corpusattestations)}</a>, <br/>)
    }</td>
</tr>
    }</tbody>
    </table>)
     ,
     if($cP lt 1) then () else
    (
   <p>{$cSp} possibilities shown parsing as particle.</p>,
morpho:selectionmessage($cSp, $cP, $fuzzy, $NoDil, $mismatch),
    <table class="table table-responsive">
<thead>
<th>Forms</th>
<th>Link Lexicon</th>
<th>TraCES Corpus</th>
</thead>
<tbody>
{for $partic in $selectionP
return 
<tr>
<td>{for $desinence in $partic//f:solution/f:forms/f:desinence return
                              ((string-join($desinence/f:*[not(name()='length')]/text(), ' ')),<br/>)
                              }</td>
<td>{for $l  in $partic/f:link return 
                (<a  target="_blank">{$l/@href, $l/text()}</a>,<br/>)}</td>
                <td>{for $l  in $partic/f:link 
    let $lex := substring-after($l/@href,'http://betamasaheft.eu/Dillmann/lemma/')
    let $corpusattestationsall := $morpho:corpus//t:f[starts-with(.,$lex)]
    let $corpusattestations := $corpusattestationsall[@name='lex']
    return (<a target="_blank" href="{$morpho:baseurl}/corpus?query={$lex}&amp;type=lemma">{count($corpusattestations)}</a>, <br/>)
    }</td>
</tr>
    }</tbody>
    </table>)
    )}</div>
   <div class="col-md-3">{ if($tracesCount gt 0) then <p class="alert alert-dismissible alert-info">This word appears in this form in the TraCES corpus <a target="_blank" class="btn btn-primary" href="{$morpho:baseurl}/corpus?query={$q}&amp;type=string">{$tracesCount}</a> times.</p>
else (<div class="alert alert-dismissible alert-info">No occurrences of this word in this form in TraCES corpus. To see if the lemma is attested in other forms, you might click one of the options in the table, in the TraCES Corpus column. <button type="button" class="close" data-dismiss="alert" aria-label="Close">
    <span aria-hidden="true">close</span>
  </button></div>)
  }</div>
</div>}
    </div>
    </div>
    </body>
</html>
};


(:~
 : Given a root prints the full paradigm as an HTML table.
 : the type of verb is guessed using morpho:guessType() on the basis of the root parameter.
 : the root can be any perfect form in the paradigm.
 :)
declare
%rest:GET
%rest:path("/morpho/paradigm")
%rest:query-param("root", "{$root}", "")
%output:method("html")
function morpho:morphoParadigm($root as xs:string*){
let $root :=  util:unescape-uri($root, 'UTF-8')
let $allrelevantPatterns := morpho:guessType($root, $morpho:patterns)
return
<html>
<head>
<meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
   
<title>{$root} paradigm</title>
 <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
</link>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
  </head>
<body>
<div class="col-md-12"><h1>Morphological Parser (alpha)</h1></div>
<div class="col-md-12">
<div class="col-md-3"><div class="col-md-12">{morpho:form()}</div></div>
<div class="col-md-9">
{for $pattern in $allrelevantPatterns
let $parent := $pattern/ancestor::f:type
group by $P := $parent
let $pos := count($P/preceding::f:type)
order by $pos
return 
(<hr/>,
<table class="table table-responsive">
<thead>
<tr><th>fidal</th><th>translit</th><th>pattern</th><th>form</th><th>conjugation</th></tr></thead>
<tbody>
{$P/@name}
{for $p in $pattern 

let $patt := $p/text()
let $fidal := morpho:pattern2form($p, $root)
let $translit := morpho:pattern2transcription($p, $root)
let $g := string($p/ancestor::f:group/@name)
let $t := string($p/ancestor::f:type/@name)
let $mode := string($p/parent::f:pattern/@name)
let $solution := ($g||','||$t||' '||$mode)
order by $p/position()
return
<tr>
 {if($p[@attested='no']) then attribute style {'color:red;'} else ()}
<td><a target="blank" href="{$morpho:baseurl}/corpus?query={$fidal}&amp;type=string">{$fidal}</a></td>
<td>{$translit}</td>
<td>{$p}</td>
<td>{$solution}</td>
<td><a target="_blank" href="{$morpho:baseurl}/conj?root={$root}&amp;mode={$mode}&amp;group={$g}&amp;type={$t}">conjugate this form</a>, or
<a target="_blank" href="{$morpho:baseurl}/conj?root={$root}&amp;mode={$mode}&amp;group={$g}&amp;type={$t}&amp;pronouns=true">conjugate this form with pronouns</a>
</td>
</tr>}
</tbody></table>)}</div></div>
</body></html>
};



(:~
 : Given a root, mode, group and type (see conjugation.xml) prints that conjugation of the verb .
 : To do this the root is parsed without awareness of prefixes and suffixes to the root itself
 : the result is returned as an HTML page with a table 
 :)
declare
%rest:GET
%rest:path("/morpho/conj")
%rest:query-param("root", "{$root}", "")
%rest:query-param("mode", "{$mode}", "Perfect")
%rest:query-param("group", "{$group}", "I")
%rest:query-param("type", "{$type}", "1a")
%rest:query-param("pronouns", "{$pronouns}", "false")
%rest:query-param("transcriptionType", "{$transcriptionType}", "BM")
%output:method("html")
function morpho:morphoConjugation($root as xs:string*, $group as xs:string*, $type as xs:string*, $transcriptionType as xs:string*,$pronouns as xs:string*, $mode as xs:string*){
(:conjugation can be done only knowing already the root of the specific type for that mode, so, starting from 1a2a3a is not possible, 
it needs to know the exact starting point to attach prefixes and suffixes, 
i.e. it can only occurr after the imput has been disambiguated.
if user gives MAIN root, then the root can be built from pattern in patterns, based on the values of the parameters
:)

(:determines the type of the verb and if to look for the main formula or for one of the w, y or larigeals :)
let $relevantPatterns:=$morpho:patterns//f:group[@name = $group]/f:type[@name=$type]/f:pattern[@name=$mode]
let $root :=  util:unescape-uri($root, 'UTF-8')(:identify the correct pattern for the root:)
let $patterns := morpho:guessType($root, $relevantPatterns)
let $pattern := $patterns[1]/text()
(:build the correct form in fidal:)
let $correctRoot := morpho:pattern2form($pattern, $root)

let $modes:=  $morpho:conjugations//f:affixes[ancestor::f:type[@name=$mode]]
let $modes := if ($pronouns = 'true') then $modes[ancestor::f:pronouns] else $modes[not(ancestor::f:pronouns)]
(:chunck the correct root in fidal into characters:)
let $chars := functx:chars($correctRoot)
(:the sequence of character going to the parsing which is due to be conjugated should be clean of conjugation itself, so ይትነገር/yǝt1a22a3 should go like ትነገር/t1a22a3 so that the conjugation can be applied from beginning to end :)
let $chars := if ($mode='Imperfect' or $mode='Subjunctive') then subsequence($chars, 2) else $chars
let $parsed := morpho:standardGeneric($chars, $root)
return
<html>
<head>
<meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
   
<title>{$mode} conjugation for {$root} ({$group},{$type})
</title>
 <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
</link>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
  
</head>
<body>
<div class="col-md-12"><h1>Morphological Parser (alpha)</h1></div>
<div class="col-md-12">
<div class="col-md-3"><div class="col-md-12">{morpho:form()}</div></div>
<div class="col-md-9">
<h1>{$mode} conjugation for <a target="_blank" href="{$morpho:baseurl}/paradigm?root={$root}">{$root}</a> ({$group},{$type})</h1>
<table class="table table-responsive">
<thead>
<tr><th>number</th><th>person</th><th>gender</th>{if ($pronouns = 'true') then <th>object suffixes</th> else ()}<th>form</th></tr>
</thead>
<tbody>
{for $affixes in $modes
let $form := morpho:conjugatedForm($parsed, $transcriptionType,$affixes, $group, $type)
let $formtext := string-join($form//f:char[not((position() != 1) and (following-sibling::f:firstOrder = parent::f:syllab/following-sibling::f:syllab/f:firstOrder))]/text())
return
<tr>
<td>{string($affixes/ancestor::f:num[not(ancestor::f:pronouns)]/@type)}</td>
<td>{string($affixes/ancestor::f:person[not(ancestor::f:pronouns)]/@type)}</td>
<td>{string($affixes/ancestor::f:gender[not(ancestor::f:pronouns)]/@type)}</td>
{if ($pronouns = 'true') then <td>
{string($affixes/ancestor::f:person[ancestor::f:pronouns]/@n)}
{substring($affixes/parent::f:gender[ancestor::f:pronouns]/@type,1,1)} {' '}
{lower-case(substring($affixes/ancestor::f:num[ancestor::f:pronouns]/@type,1,4))}</td>
else ()}
<td><a target="blank" href="{$morpho:baseurl}/corpus?query={$formtext}&amp;type=string">{ 
(:the selector in the chars makes sure that gemination is not reproduced in the fidal:)
$formtext
}</a></td>
</tr>
}
</tbody>
</table></div></div>
</body>
</html>
};



(:~
 : Given lexical item or a string looks in the traces texts for attestations, forms and morphological annotation.
 : type can be either lemma id or string
 :)
declare
%rest:GET
%rest:path("/morpho/corpus")
%rest:query-param("query", "{$query}", "")
%rest:query-param("type", "{$type}", "")
%output:method("html")
function morpho:morphoCorpus($query as xs:string*, $type as xs:string*){

let $query := if($type='string') then util:unescape-uri($query, 'UTF-8') else $query 
let $selector := if($type='lemma') (:lemma ID:)
then ($morpho:corpus//t:f[@name='lex'][starts-with(.,$query)]) 
else (:string:)
($morpho:corpus//t:f[@name='fidäl'][.=$query])
let $total := count($selector)

return
<html>
<head>
<meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
   
<title>{$query} TraCES corpus data for {$type}</title>
 <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
</link>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
  </head>
<body>
<div class="col-md-12"><h1>Morphological Parser (alpha)</h1>
<h2>{$total} TraCES corpus annotations for {$type}:  {$query} </h2>
<table class="table table-responsive">
<thead>
<tr><th>fidal</th><th>annotations</th></tr></thead>
<tbody>

{

for $occurrence in $selector
let $graphunit:= $occurrence/ancestor::t:fs[@type='graphunit'][1]
let $fidal := $graphunit/t:f[@name="fidäl"]/text()
group by $F := $fidal

let $count := count($morpho:corpus//t:f[@name='fidäl'][.=$F])
order by $count descending
return
<tr>
<td><a target="_blank" href="{$morpho:baseurl}?query={$F}">{$F}</a> (<a target="_blank" href="{$morpho:baseurl}/corpus?query={$F}&amp;type=string">{$count}</a>)</td>
<td>{for $occ at $p in $occurrence 
                        let $thisgraphunit:= $occ/ancestor::t:fs[@type='graphunit'][1]
                        let $translit := $thisgraphunit/t:f[@name="translit"]/text() 
                        let $description := for $morpho in $thisgraphunit//t:fs[@type="morpho"] 
                                                                        let $desc := string-join($morpho//text()[not(parent::t:f[@name='lex'])], ' ')
                                                                        let $linklemma := substring-before($morpho//t:f[@name='lex']/text(), '--')
                                                                        let $linktext := substring-after($morpho//t:f[@name='lex']/text(), '--')
                                                                        let $dillLink := <a target="_blank" href="http://betamasaheft.eu/Dillmann/lemma/{$linklemma}"> [See in Dillmann]</a>
                                                                        let $link := <a target="_blank" href="{$morpho:baseurl}/corpus?query={$linklemma}&amp;type=lemma">{$linktext}</a>
                                                                                    return ($desc, $link,$dillLink,<br/>)
                        let $source := string($occurrence/ancestor::t:TEI/@corresp)
                        let $section := $thisgraphunit/ancestor::t:div[@type]
                    return
($p,
<table class="table table-responsive">
<thead>
<tr>
<th>translit</th>
<th>form</th>
<th>source</th>
<th>section</th>
</tr></thead>
<tbody>
<tr>
<td>{$translit}</td>
<td>{$description}</td>
<td><a href="http://betamsaheft.eu/{$source}">{$source}</a></td>
<td>{for $div in $section return string($div/@type)||': '||string($div/@n)}</td>
</tr>
</tbody>
</table>)
}</td>
</tr>

}</tbody></table></div>
</body></html>
};


(:~
 : the single query going to any of the main entry points needs to be weeded of negation and checked for consistency with the input script
 : enters a string returns a sequence which might be made of only one string
 :)
declare function morpho:cleanQ($query, $fidal, $transcriptionType){
let $query:= util:unescape-uri($query, 'UTF-8')
(:check if it is really fidal:)
let $query := if ($fidal = 'false' or (not(matches($query, '\p{IsEthiopic}')))) 
                            then try{morpho:transcription2fidal($query, $transcriptionType)} 
                                        catch*{$err:description} 
                           else $query
(:splits proclitics:)
let $query := for $proclitic in ($morpho:proclitics, $morpho:pronouns)//f:proclitic
                        let $p := $proclitic/text()
                    return 
                    if(starts-with($query, $p)) then ($p, $query, substring-after($query, $p)) else $query
(:remove negation:)
let $query := for $q in $query return 
                            if (starts-with($q, $morpho:neg)) then ($morpho:neg, $q, substring-after($q, $morpho:neg)) else $q

return
distinct-values($query)
};


(:~
 : depending on the parameter set, any of the main entry query needs to filter down the results accordingly. The default selector is the stricter.
 :)
declare function morpho:selection($results, $fuzzy, $NoDil, $mismatch){
         if($fuzzy='false' and $NoDil = 'true' and $mismatch = 'false') then $results//f:*[child::f:match[not(@fuzzy)]][not(parent::f:patternRootMismatch)]
else if($fuzzy='true' and $NoDil = 'false' and $mismatch = 'false') then $results//f:InDillmann[child::f:match][not(parent::f:patternRootMismatch)]
else if($fuzzy='true' and $NoDil = 'true' and $mismatch = 'false') then $results//f:*[child::f:match][not(parent::f:patternRootMismatch)]
else if($fuzzy='false' and $NoDil = 'true' and $mismatch = 'true') then $results//f:*[child::f:match[not(@fuzzy)]]
else if($fuzzy='true' and $NoDil = 'false' and $mismatch = 'true') then $results//f:InDillmann[child::f:match]
else if($fuzzy='false' and $NoDil = 'false' and $mismatch = 'true') then $results//f:InDillmann[child::f:match[not(@fuzzy)]]
else if($fuzzy='true' and $NoDil = 'true' and $mismatch = 'true') then $results//f:*[child::f:match]
          else 
(:          false, false, false is the default:)
          $results//f:InDillmann[child::f:match[not(@fuzzy)]][not(parent::f:patternRootMismatch)]};


(:~
 : depending on the parameters set, a different selection of results is returned and the following message based on those parameters informs the user about what is available.
 :)
declare function morpho:selectionmessage($total, $partial, $fuzzy, $NoDil, $mismatch){
<div class="alert alert-info alert-dismissible">
<p>{if($fuzzy='false' and $NoDil = 'true' and $mismatch = 'false') then 'You are seeing ' || $total ||' out of '  || $partial || 
'. You are not seeing any pattern matching which is not consistent with the reconstructed root. You are not seeing results of fuzzy search.'  
else if($fuzzy='true' and $NoDil = 'false' and $mismatch = 'false') then  'You are seeing ' || $total ||' out of '  || $partial || 
' because we have filtered out all entries whose reconstructed root is not in the online Dillmann Lexicon Linguae Aethiopicae. 
You are not seeing any pattern matching which is not consistent with the reconstructed root. '  
else if($fuzzy='true' and $NoDil = 'true' and $mismatch = 'false') then  'You are seeing ' || $total ||' out of '  || $partial || 
'. You are not seeing any pattern matching which is not consistent with the reconstructed root. '  
else if($fuzzy='false' and $NoDil = 'true' and $mismatch = 'true') then 'You are seeing ' || $total ||' out of '  || $partial || 
'. You are not seeing results of fuzzy search.'  
else if($fuzzy='true' and $NoDil = 'false' and $mismatch = 'true') then  'You are seeing ' || $total ||' out of '  || $partial || 
' because we have filtered out all entries whose reconstructed root is not in the online Dillmann Lexicon Linguae Aethiopicae. '  
else if($fuzzy='false' and $NoDil = 'false' and $mismatch = 'true') then  'You are seeing ' || $total ||' out of '  || $partial || 
' because we have filtered out all entries whose reconstructed root is not in the online Dillmann Lexicon Linguae Aethiopicae.You are not seeing results of fuzzy search.'  
else if($fuzzy='true' and $NoDil = 'true' and $mismatch = 'true') then  'You are seeing ' || $total ||' out of '  || $partial || '.'  
else  'You are seeing ' || $total ||' out of '  || $partial || ' because we have filtered out all entries whose reconstructed root is not in the online Dillmann Lexicon Linguae Aethiopicae. 
You are not seeing any pattern matching which is not consistent with the reconstructed root. You are not seeing results of fuzzy search.' }</p>
<button type="button" class="close" data-dismiss="alert" aria-label="Close">
    <span aria-hidden="true">close</span>
  </button></div>
};

(:~
 : Given a root in the 1a2a3a pattern, guesses the root and returns only the patterns from patterns.xml which are relevant to that type
 :)
declare function morpho:guessType($root, $patterns as node()){
(:expects for $root the 1a2a3a type!! :)
let $first := substring($root, 1,1)
let $type := if(contains($root, $morpho:waw)) then 'w' 
else if (contains($root, $morpho:yod)) then 'y' 
else if (contains($root,'አ') or contains($root,'ሀ') or contains($root,'ሐ') or contains($root,'ኀ') or contains($root,'ዐ')) then 'l'
else 'regular'
let $chars := functx:chars($root)
let $typeNum := if($type='regular') then () else 
                                    switch($type) 
                                    case 'w' return index-of($chars,$morpho:waw)
                                    case 'y' return index-of($chars,$morpho:yod)
                                    default return if (contains($root,'አ')) then index-of($chars,'አ')
                                                                else if (contains($root,'ሀ')) then index-of($chars,'ሀ')
                                                                else if (contains($root,'ሐ')) then index-of($chars,'ሐ')
                                                                else if (contains($root,'ኀ')) then index-of($chars,'ኀ')
                                                                else index-of($chars,'ዐ')
let $vtype := ($type||$typeNum)

let $allpatterns := if ($type='regular') then $patterns//f:formula[not(@type)]
                                                        else $patterns//f:formula[@type=$vtype] 
    let $dentalSybilantNormal := if ($morpho:sibilants = $first ) then $allpatterns[not(contains(.,'DD'))]
                                                                else if ($morpho:dentals = $first) then $allpatterns[not(contains(.,'SS'))]
                                                                else $allpatterns[not(contains(.,'DD'))][not(contains(.,'SS'))]
    return 
    $dentalSybilantNormal
};


(:~
 : replaces values in a string to create multiple options  used by morpho:subs()
 :)
declare function morpho:repl($query, $match, $sub)
{
(: take the string and make into a sequence eg. abcabc   :)
    let $seq :=
        for $ch in string-to-codepoints($query)
        return codepoints-to-string($ch)
(:        loop the sequence (a,b,c,a,b,c):)
    for $x in $seq
(:    get the position of the character in the sequence, a = (0, 3):)
    return
        if ($x = $match) then
         let $index := index-of($seq, $x)
         return
(:    loop each occurrence of that character to do the substitutions one by one in case it matches, 0 and 3 for the example:)
    for $i in $index
    
    return
(:        substitute only that occurence by removing it and adding the substitute in its place, so in the first loop, remove a and then add d before position 0:)
            let $rem := remove($seq, $i)
            let $add := insert-before($rem, $i, $sub)
            let $newstring := string-join($add, '')
(:          returns the string dbcabc and sends the same over again to this template.  :)
            return
           ($newstring,
           morpho:repl($newstring, $match, $sub))
            
        else
(:          there character does not match and the string is returned  :)
            string-join($seq, '')
            
(:            this generates an exponential number of options which are the same, but can then be filtered with distinct-values() :)
};


(:~
 : function used by morpho:shva() to perform the replacements in a string
 :)
declare function morpho:subs($query, $homophones, $mode) {
    let $all :=
    for $b in $homophones
    return
    for $q in $query return
        if (contains($q, $b)) then
            let $options := for $s in $homophones[. != $b]
            return
                (distinct-values(morpho:repl($q, $b, $s)),
                if ($mode = 'ws') then
                    (replace($q, $b, ''))
                else
                    ())
             let $checkedoptions := for $o in $options return
             if ($o = $query) then () else $o
            return
                $checkedoptions
        else
            ()
   let $queryAndAll := ($query, $all)
   return distinct-values($queryAndAll)
};

(:~
 : given a string with ǝ calls the morpho:subs function fo return alternatives with and without ǝ
 :)
declare function morpho:shva($formula){if (contains($formula, 'ǝ')) then (
        let $e := ('','ǝ') return morpho:subs($formula, $e, 'normal')) else $formula};


(:~
 : used by function parsing the string to return structured information on a single Fidal character
 : without position
 :)
declare function morpho:char($char, $first, $ord, $tr){
<char xmlns="http://fidal.parser">{$char}</char>,
<firstOrder xmlns="http://fidal.parser">{$first}</firstOrder>,
<order xmlns="http://fidal.parser">{$ord}</order>,
<transcription  xmlns="http://fidal.parser">{$tr}</transcription>
};

(:~
 : used by function parsing the string to return structured information on a single Fidal character
 : with position
 :)
declare function morpho:char($char, $first, $pos, $ord, $tr){
<char xmlns="http://fidal.parser">{$char}</char>,
<firstOrder xmlns="http://fidal.parser">{$first}</firstOrder>,
<position xmlns="http://fidal.parser">{$pos}</position>,
<order xmlns="http://fidal.parser">{$ord}</order>,
<transcription  xmlns="http://fidal.parser">{$tr}</transcription>
};

(:~
 : used by function parsing the string to return structured information on a single Fidal character part of the prefix of a form
 :)
declare function morpho:prefix($char, $first, $ord, $tr){
<prefix xmlns="http://fidal.parser">
{morpho:char($char, $first, $ord, $tr)}
</prefix>
};

(:~
 : used by function parsing the string to return structured information on a single Fidal character 
 :)
declare function morpho:syllab($char, $first, $pos, $ord, $tr){
<syllab xmlns="http://fidal.parser">
{morpho:char($char, $first, $pos, $ord, $tr)}
</syllab>
};

(:~
 : used by function parsing the string to return structured information on a single Fidal character part of the suffix of a form
 :)
declare function morpho:suffix($char, $first, $pos, $ord, $tr){
<suffix xmlns="http://fidal.parser">
{morpho:char($char, $first, $pos, $ord, $tr)}
</suffix>
};

(:~
 : used by function parsing the string in case a AST form is detected
 :)
declare function morpho:asta($chars, $query){ 
<chars xmlns="http://fidal.parser">
                    {switch(substring($query, 1,1))
                    case 'ያ' return 
                    morpho:prefix('ያ','የ',4,'y')
                    default return 
                    morpho:prefix('አ','አ',1,'ʾ')
                    }
                    {morpho:prefix('ስ','ሰ',6,'s')}
                    {morpho:prefix('ተ','ተ',1,'t')}
                    {for $c at $p in subsequence($chars, 4)
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                if((($p+3)=count($chars)) and $chars[last()]='ት') then 
                morpho:suffix($c,$letter/parent::f:realizations/f:realization[2]/text(),($p +3),count($letter/preceding-sibling::f:realization), $letter/ancestor::f:letter/f:transcription/text())
                    else
                    morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),($p +3),count($letter/preceding-sibling::f:realization), $letter/ancestor::f:letter/f:transcription/text())
                }
                </chars>};
                
  (:~
 : used by function parsing the string in case a very short sequence is detected
 :)              
declare function morpho:short($chars, $Wpos){
                
                <chars xmlns="http://fidal.parser">
                    {for $c at $p in $chars
                    let $posInc := if ($Wpos = 1) then ($p +$Wpos) else if ($Wpos = 2) then (switch($p) case 1 return 1 case 2 return 3 default return $p) else if ($Wpos = 3) then (switch($p) case 1 return 1 case 3 return 2 default return $p) else ()
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                    morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),$posInc,count($letter/preceding-sibling::f:realization), $letter/ancestor::f:letter/f:transcription/text())
                }
                </chars>
                };
                
                
(:~
 : used by function parsing the string in case a short standard form is detected
 :)                
declare function morpho:standardshort($chars){<chars xmlns="http://fidal.parser">{for $c at $p in $chars
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                    if(($p=1) and (count($chars) ge 3) and (($c='ይ') or ($c='ያ') or ($c='አ') or ($c='ት') or ($c='ተ') or ($c='ን'))) then 
                    morpho:prefix($c,$letter/parent::f:realizations/f:realization[2]/text(),count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                    else if(($p=count($chars)) and (count($chars) ge 3) and ($c='ት')) then 
                    morpho:suffix($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                    else
                    morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                     }
                     </chars>};
                

(:~
 : used by function parsing the string
 : attempts at isolating prefixes and suffixes to the root
 :)
declare function morpho:standard($chars, $query){<chars xmlns="http://fidal.parser">{
let $cnt := count($chars)
return
                for $c at $p in $chars
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                    if((($p=1) or ($p=2)) and ($cnt gt 4) and (starts-with($query, 'ይት'))) then 
                    morpho:prefix($c,$letter/parent::f:realizations/f:realization[2]/text(),count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                    else  if(($p=1) and ($cnt gt 3) and (($c='ይ') or ($c='ያ') or ($c='የ') or ($c='አ') or ($c='ት') or ($c='ተ') or ($c='ን'))) then 
                    morpho:prefix($c,$letter/parent::f:realizations/f:realization[2]/text(),count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                   (: else if(($p=count($chars)) and (count($chars) gt 3) and ($c='ት')) then 
                    morpho:suffix($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                  :)  else
                    morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                     }
                     </chars>};
          
          (:~
 : used by function parsing the string
 : attempts at isolating prefixes and suffixes to the root
 :)
declare function morpho:standardNoun($chars, $query){<chars xmlns="http://fidal.parser">{
let $cnt := count($chars)
return
                for $c at $p in $chars
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                    if(($p=1) and ($cnt gt 4) and (($c='መ') or ($c='ም'))) then 
                    morpho:prefix($c,$letter/parent::f:realizations/f:realization[2]/text(),count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                     else
                    morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
                     }
                     </chars>};
          
(:~
 : used by function parsing the string. It does not try to identify prefixes and suffixes
 :)
declare function morpho:standardGeneric($chars, $query){
<chars xmlns="http://fidal.parser">{
for $c at $p in $chars
                let $letter := $morpho:letters//f:realization[. = $c]
                return
                  morpho:syllab($c,$letter/parent::f:realizations/f:realization[2]/text(),$p,count($letter/preceding-sibling::f:realization),$letter/ancestor::f:letter/f:transcription/text())
}</chars>
};


(:~ 
: given the string as a sequence of characters goes through them one by one and tries to identify main types to send to the correct parsing function, which will make from the sequence a structured XML 
: fragment with all the relevant information for each character
:)
declare function morpho:parseChars($chars,$query,$type){
if ($type ='noun') then morpho:standardNoun($chars, $query)
(:IV types:)             
 else if(count($chars) ge 6 and (starts-with($query, 'አስተ') or starts-with($query, 'ያስተ'))) 
            then  morpho:asta($chars, $query)       
(:       shortened forms         :)
  else if((count($chars) lt 3) and ($type !='regular')and ($type !='fuzzy')) then 
             let $num := switch($type) case 'w2' return 2 case 'w3' return 3 default return 1
             return
                 morpho:short($chars, $num)
  else if(count($chars) eq 3 and ($type !='regular')and ($type !='fuzzy')) then 
             morpho:standardshort($chars)
   else             
            morpho:standard($chars, $query)
};
                     
(:~
 : given a character returns the fidal letter in the first order for the 1a2a3a pattern
 :)
declare function morpho:rootbuilder($position, $c,$rootpattern, $transcriptionType){
      let $transcription := $c/f:transcription/text()
      let $subs := substring-after($rootpattern, string($position))
     let $vowel := substring($subs, 1,1)
     let $vowelposition :=  if (matches($vowel, '\d'))  (:  geminated:)
                                                 then 0 
                                                 else count($morpho:letters//f:vowel[.=$vowel][parent::f:transcription[@type=$transcriptionType]]/preceding-sibling::f:vowel)
       let $tr := $morpho:letters//f:letter[f:transcription=$transcription]
       return
      $tr//f:realization[position()=($vowelposition+1)]/text()
                                                                            
};

(:~
 : from the structured data about a string returns an initial flat formula which can be transformed in potential patterns
 :)
declare function morpho:formula ($consVowl, $transcriptionType){
let $formulaparts := for $conVow at $s in $consVowl//f:* 
                                    let $p := $conVow/f:order
                                    return
                                    if($conVow/name() = 'prefix') 
                                    then 
                                          ($conVow/f:transcription/text(), $morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]][position()=($p+1)]) 
                                          
                                   else if($conVow/name() = 'suffix') 
                                    then 
                                          ($conVow/f:transcription/text(), $morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]][position()=($p+1)]) 
                                    else
                                          (($conVow/f:position - count($consVowl//f:prefix)), $morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]][position()=($p+1)])
                                          return string-join($formulaparts)
};

(:~
 : builds a list of roots which can be the main one, 1a2a3a formatted and a list of roots for all Perfect forms (the ones which can be looked up in the Dillmann Lexicon Linguae Aethiopicae lemma.xml list
 : depending on the type of the verb, inserts W, Y or a Laringeal as options
 :)
declare function morpho:listroots($match, $maintype, $consVowl, $transcriptionType, $type, $f){
                                                                   let $rootpatternmaster := $morpho:patterns//f:pos[@name='verb']/f:group[@name='I']/f:type[@name = $type]/f:pattern[1]/f:formula
                                                                   let $rootpat := 
                                                                           if($maintype='regular' or $maintype='fuzzy') 
                                                                           then $rootpatternmaster[not(@type)] 
                                                                           else $rootpatternmaster[@type=$maintype][not(@attested)][1]
                                                                   let $rootpattern := $rootpat/string()
                                                                   let $mainRoots := 
                                                                   <mainroots  xmlns="http://fidal.parser">{
                                                                   $rootpat/@type,
                                                                   if ($maintype='regular' or $maintype='fuzzy') then (
                                                                   <root  xmlns="http://fidal.parser">{(if(not(contains($f , '1'))) then (
                                                                   morpho:rootbuilder(1, $consVowl/f:prefix[last()],$rootpattern, $transcriptionType)
                                                                   
                                                                   ) else (),
                                                                     for $c at $s in $consVowl/f:syllab[position() le 3]
                                                                     return
                                                                     morpho:rootbuilder(($c/f:position - count($consVowl/f:prefix)), $c,$rootpattern, $transcriptionType)
                                                                      )}</root>)
                                                                   else (
                                                                   let $letter := substring($maintype, 1,1)                                                                   
                                                                   let $position := substring($maintype, 2,1)
                                                                   let $variantletterfrompattern := switch($letter) case 'w' return ($morpho:waw) case 'l' return $morpho:laryngeals default return ($morpho:yod)
                                                                   let $firstorderletters:= $consVowl//f:firstOrder/text()
                                                                   let $variantletter := $variantletterfrompattern[.=$firstorderletters]
                                                                   return 
                                                                   switch($position) 
                                                                   case '1' return
                                                                   for $v in $variantletter 
                                                                   return 
                                                                   <root  xmlns="http://fidal.parser">{($v,
                                                                    for $c at $s in $consVowl/f:syllab[(number(f:position) - count($consVowl/f:prefix)) gt 1][(number(f:position) - count($consVowl/f:prefix)) le 3]
                                                                     return
                                                                     morpho:rootbuilder(($c/f:position - count($consVowl/f:prefix)), $c,$rootpattern, $transcriptionType)
                                                                      ) }</root>
                                                                      case '2' return
                                                                    for $v in $variantletter return 
                                                                   <root  xmlns="http://fidal.parser">{(for $c at $s in $consVowl/f:syllab[(number(f:position) - count($consVowl/f:prefix)) eq 1]
                                                                     return
                                                                     morpho:rootbuilder(($c/f:position - count($consVowl/f:prefix)), $c,$rootpattern, $transcriptionType)
                                                                     ,
                                                                     $v
                                                                     ,
                                                                     for $c at $s in $consVowl/f:syllab[(number(f:position) - count($consVowl/f:prefix)) eq 3]
                                                                     return
                                                                     morpho:rootbuilder(($c/f:position - count($consVowl/f:prefix)), $c,$rootpattern, $transcriptionType)
                                                                     
                                                                     )}</root>
                                                                     case '3' return
                                                                      for $v in $variantletter return 
                                                                     <root xmlns="http://fidal.parser">{(for $c at $s in $consVowl/f:syllab[(number(f:position) - count($consVowl/f:prefix)) lt 3]
                                                                     return
                                                                     morpho:rootbuilder(($c/f:position - count($consVowl/f:prefix)), $c,$rootpattern, $transcriptionType)
                                                                     ,
                                                                     $v
                                                                     )}</root>
                                                                   default return
                                                                   '' )}</mainroots>
                                                                   
                                                                   let $otherRoots := <otherroots xmlns="http://fidal.parser">{
                                                                                                        for $mainR in $mainRoots//f:root 
                                                                                                        let $posspatterns := if($maintype='regular' or $maintype='fuzzy') 
                                                                                                                                        then $morpho:patterns//f:formula[not(@type)][parent::f:pattern[not(parent::f:type[@name='1a'])][not(ancestor::f:group[@name='I'])][not(preceding-sibling::f:pattern)]][not(@type)]
                                                                                                                                        else $morpho:patterns//f:formula[@type=$maintype][parent::f:pattern[not(parent::f:type[@name='1a'])][not(ancestor::f:group[@name='I'])][not(preceding-sibling::f:pattern)]]
                                                                                                        return for $patt in $posspatterns return <root>{morpho:pattern2form($patt/text(),$mainR/text())}</root>}</otherroots>
                                                                   return
                                                                   
                                                                   <roots xmlns="http://fidal.parser">{$mainRoots, $otherRoots}</roots>
};

declare function morpho:rootType($mainRoot){  
    let $mainRootSeq := functx:chars($mainRoot[1])
(: in case of laringeals, there might be more than one optional root at the moment: needs to check in the consVowl which one to take! :)
    let $check := for $position at $p in $mainRootSeq return 
                                 if($position = $morpho:waw) then 'w'||$p 
                                 else if($position = $morpho:yod) then 'y'||$p 
                                 else if($position= $morpho:laryngeals) then 'l'||$p 
                                 else ''
    let $checks := distinct-values($check)
    return
       if(count($checks) le 1) then ('regular') else $checks
};

(:~
 : pattern matching for VERBS
 : goes through each hypothetic pattern and checks if it exists (thus excluding immediately all the impossible ones) 
 : for each candidate patterns builds a XML fragment with the core information and builds a list of candidate matches.
 : each match is then checked for consistency against the Dillmann LLAe and for consistency between the root and the pattern
 :)
declare function morpho:matches($allformulas, $transcriptionType,$consVowl, $maintype, $possibleDesinences){
for $f in distinct-values($allformulas)
let $matchings := if($maintype = 'fuzzy') then (let $fuzzy := concat($f,'~0.8') return $morpho:patterns//f:formula[ft:query(., $fuzzy)]) else $morpho:patterns//f:formula[. = $f]
 let $candidates:=  if(count($matchings) ge 1) then 
                                    for $match in $matchings
                                    (:    once the pattern is known, and thus for every matched pattern, the root can be computed, by looking at the pos and for verbs at the third person masculin singular  of the perfect  :) 
                                     let $typ := string($match/parent::f:pattern/parent::f:type/@name)
                                     let $type := if($typ = '2' or $typ = '3') then '1a' else $typ
                                     let $Roots :=morpho:listroots($match, $maintype, $consVowl, $transcriptionType, $type, $f)
                                     let $rootlength :=3 + count($consVowl/f:prefix)
                                    let $mainRoot := $Roots//f:mainroots/f:root/text()   
                                    let $roottype := morpho:rootType($mainRoot)
                                    
                                    let $patterntype := if($match/@type) then string($match/@type) else 'regular'
                                   let $mode := string($match/ancestor::f:pattern/@name)                 
                                             return 
                                             <match xmlns="http://fidal.parser">
                                             {if($maintype = 'fuzzy') then attribute fuzzy {'yes'} else ()}
                                             <pattern>{$match/@attested}{$f}</pattern>
                                             <patterntype>{$patterntype}</patterntype>
                                             <mainroottype>{for $r in $roottype 
                                             return <type>{$r}</type>}</mainroottype>
                                             <solution>
                                                <pos>{string($match/ancestor::f:pos/@name)}</pos>
                                                <group>{string($match/ancestor::f:group/@name)}</group>
                                                <type>{string($match/ancestor::f:type/@name)}</type>
                                                <mode>{$mode}</mode>
                                                <forms>{for $form in $possibleDesinences[f:mode = $mode][number(f:length) = $rootlength]
                                                let $desLength:= string-length($form/f:affix)
                                                order by $desLength descending
                                                return $form}</forms>
                                             </solution>
                                                {$Roots}
                                             </match>
                                             
                                   else ()
                                   
                                   
(:                                   check the lemmas in Dillmann. if it is not there, wrap it up, it is less possibly a candidate:)
 let $candidates:= for $cand in $candidates return morpho:checkDill($cand)
 
(: filter again all to check for mismatching patterns:)
     for $cand in $candidates   return  morpho:checkMismatches($cand)
};


(:~
 : pattern matching for Nouns
 : goes through each hypothetic pattern and checks if it exists (thus excluding immediately all the impossible ones) 
 : for each candidate patterns builds a XML fragment with the core information and builds a list of candidate matches.
 : each match is then checked for consistency against the Dillmann LLAe and for consistency between the root and the pattern
 :)
declare function morpho:matchesNouns($allformulas, $transcriptionType,$consVowl, $maintype, $possibleDesinences){
for $f in distinct-values($allformulas)
let $matchings := if($maintype = 'fuzzy') then (let $fuzzy := concat($f,'~0.8') return $morpho:nominal//f:formula[ft:query(., $fuzzy)]) else $morpho:nominal//f:formula[. = $f]
 let $candidates:=  if(count($matchings) ge 1) then 
                                    for $match in $matchings
                                    let $matchType := if(ends-with($match, 'i')) then 'i' else if (ends-with($match, 'e')) then 'e' else 'consonant'
                                    (:    once the pattern is known, and thus for every matched pattern, the root can be computed, by looking at the pos and for verbs at the third person masculin singular  of the perfect  :) 
                                     let $patterntype := if($match/@type) then string($match/@type) else 'regular'
                                    let $mainRoot := string-join($consVowl//f:char[number(following-sibling::f:position) le 3]/text())
                                     let $roottype := morpho:rootType($mainRoot)
                                     
                                     let $mode := string($match/ancestor::f:pattern/@name)                                             
                                             return 
                                             <match xmlns="http://fidal.parser">
                                             {if($maintype = 'fuzzy') then attribute fuzzy {'yes'} else ()}
                                             <pattern>{$match/@attested}{$f}</pattern>
                                             <patterntype>{$patterntype}</patterntype>
                                             <mainroottype>{for $r in $roottype 
                                             return <type>{if(starts-with($r, 'w')) then 'regular' 
                                            else if(starts-with($r, 'y')) then 'regular' 
                                            else $r}</type>}</mainroottype>
                                             <solution>
                                                <pos>{string($match/ancestor::f:pos/@name)}</pos>
                                                <group>{string($match/ancestor::f:group/@name)}</group>
                                                <type>{string($match/ancestor::f:type/@name)}</type>
                                                <mode>{$mode}</mode>
                                                <forms>{for $form in $possibleDesinences[f:type=$matchType][number(f:length) = 3]
                                                let $desLength:= string-length($form/f:affix)
                                                order by $desLength descending
                                                return $form}</forms>
                                             </solution>
                                             <roots><mainroots><root>{$mainRoot}</root></mainroots></roots>
                                             </match>
                                             
                                   else ()
                                   
             let $candidates:= for $cand in $candidates return morpho:checkDill($cand)                      
(: filter again all to check for mismatching patterns:)
     for $cand in $candidates                                   return   morpho:checkMismatches($cand)
};


(:~
 : for each candidate match checks for lemmas in Dillmann Lexicon Linguae Aethiopicae and returns a list of links to those.
 : the entry is marked as InDillmann or as a RootNotInDillmann, but the results are preserved
  :)
declare function morpho:checkDill($cand){
let $dillmanncheck := for $r in $cand//f:root/text()
                                             let $dillmannlemmas  := $morpho:lemmas//t:foreign[.=$r]
(:                                             let $dillmannlemmas := if($cand//f:pos = 'verb') then $dillmannlemmas[parent::f:lemma[@type='root']] else $dillmannlemmas:)
                                             return if(count($dillmannlemmas) ge 1) 
                                                         then 
                                                         for $d in $dillmannlemmas return 
                                                         map{'link':=string($d/parent::f:lemma/@xml:id), 'root':=$r} else ()
return 
        if(count($dillmanncheck) ge 1) 
        then <InDillmann xmlns="http://fidal.parser">{$cand}
        {for $lemma in $dillmanncheck 
        return 
        <link href="http://betamasaheft.eu/Dillmann/lemma/{$lemma('link')}">
        {$lemma('root')}
        </link>
        }</InDillmann>
        else <RootNotInDillmann xmlns="http://fidal.parser">{$cand}</RootNotInDillmann>
(:                       This check is not enough, but there is no way to tell in Dillmann data if an entry is a verb. the information is in I,1 and similar, but is not marked up. it could be and there is an issue about that.         :)
};


(:~
 : for each candidate match checks that the pattern is consistent with the root.
 : the entry is wrapped in an element patternRootMismatch if a problem is encountered, but the results are preserved
  :)
declare function morpho:checkMismatches($cand){
let $MRT :=$cand//f:mainroottype/f:type/text()
let $PT := $cand//f:patterntype/text()                           
return
 if($PT= $MRT) 
                                   then <patternOk xmlns="http://fidal.parser">{$cand}</patternOk> 
                                   else  <patternRootMismatch xmlns="http://fidal.parser">{$cand}</patternRootMismatch>
         
};

(:~
 : given a transcription, produces the Fidal. Please, note that the reverse is possible only from the pattern, not from the transcription.
 :)
declare function morpho:transcription2fidal($trans,$transcriptionType){
let $vowels := $morpho:letters//f:transcription[@type=$transcriptionType]//f:vowel/text()
let $regex := '(([ṭṗṣḍḫčḥśʿʾbcdfghlmnpqrstvzwyxk])(ʷ?['||string-join($vowels)||']?))'
let $analyze := analyze-string($trans, $regex)
let $query := for $group in $analyze//s:group[@nr='1']
                        let $cons := $group/s:group[@nr='2']
                        let $vowel := $group/s:group[@nr='3']
                        return
                        if ($cons = $group/following::s:group[1]/s:group[@nr="2"]) then () else
                        let $orderVow:= if($vowel='') then 0 else count($morpho:letters//f:transcription[@type=$transcriptionType]/f:vowel[.=$vowel]/preceding-sibling::f:vowel)
                        let $fidal := $morpho:letters//f:transcription[.=$cons]/following-sibling::f:realizations/f:realization[$orderVow+1]/text()   
                        return $fidal
return 
string-join($query)
};


(:~
 : simply goes through the parsed string and prints a basic transcription, agnostic, which is used to match the endings and find possible desinences.
 :)
declare function morpho:genericTranscription($parsed){
for $syl in $parsed/f:syllab 
                                            let $t := $syl/f:transcription 
                                            let $o := number($syl/f:order) +1
                                            return 
                                            ($morpho:letters//f:transcription[.=$t]/text() ||$morpho:letters//f:vowel[parent::f:transcription[@type="BM"]][position()=$o]/text() )
};

(:~
 : givena  transcription parses it into an XML fragment with structured information about the string
 :)
declare function morpho:transcription2chars($trans,$pos,$transcriptionType){
let $vowels := $morpho:letters//f:transcription[@type=$transcriptionType]//f:vowel/text()
let $regex := '(([ṭṗṣḍḫčḥśʿʾbcdfghlmnpqrstvzwyxk])(ʷ?['||string-join($vowels)||']?))'
let $analyze := analyze-string($trans, $regex)
let $syllabs := for $group at $s in $analyze//s:group[@nr='1']
                        let $cons := $group/s:group[@nr='2']
                        let $vowel := $group/s:group[@nr='3']
                        return
                        let $orderVow:= if($vowel='') then 0 else count($morpho:letters//f:transcription[@type=$transcriptionType]/f:vowel[.=$vowel]/preceding-sibling::f:vowel)
                        let $fidal := $morpho:letters//f:transcription[.=$cons]/following-sibling::f:realizations/f:realization[$orderVow+1]/text()   
                        let $first :=  $morpho:letters//f:transcription[.=$cons]/following-sibling::f:realizations/f:realization[2]/text()
                        return 
                        <syllab xmlns="http://fidal.parser">
{morpho:char($fidal, $first, ($pos +$s), $orderVow, $cons/text())}
</syllab>
return 
$syllabs
};

(:~
 : given a structured parsed string, and the list of affixes in conjugation.xml, builds the selected forms, applying some of the rules in a generic way, so that they can be valid in most cases
 :)
declare function morpho:conjugatedForm($parsed, $transcriptionType,$affixes, $group, $type){

let $secondradicalIndex := if ($group = 'IV') then 5 else 2
let $affixesStruct :=(if($affixes/f:affix[@type='pre']) then ($affixes/f:affix[@type='pre']/text()|| '-' || ' ') else ())|| (if($affixes/f:affix[not(@type)]) then ('-' || string-join($affixes/f:affix[not(@type)]/text(), ' / ')) else ())
let $prefix:=$affixes/f:affix[@type='pre'] 
let $affix:=$affixes/f:affix[not(@type)][1] 
let $lastSyllab := $parsed/f:syllab[last()]
let $o := number($lastSyllab/f:order) +1 
let $lastVowel := $morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]][position()=$o]/text()
let $firstletterofaffix := substring($affix, 1, 1)
let $vowels := $morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]]
                            return
                            <form affix="{$affixesStruct}">
                            <chars xmlns="http://fidal.parser">
                            {(:                            prefix:)
                            if(count($prefix) ge 1) then
                            let $prefix := if($group = 'II' or $group='IV') then replace($prefix, 'ə', 'ā') 
                                                        else if ($parsed/f:syllab[1]/f:firstOrder = $morpho:laryngeals) then replace($prefix, 'ə', 'a') 
                                                        else $prefix
                            let $prefixCons := substring($prefix, 1,1)
                            let $prefixVowel := substring($prefix, 2,1)
                            let $ord := count($vowels[.=$prefixVowel]/preceding-sibling::f:vowel)
                            let $firstOrder := $morpho:letters//f:transcription[.=$prefixCons]/following-sibling::f:realizations/f:realization[2]/text()
                            let $ch := $morpho:letters//f:realization[.=$firstOrder]/parent::f:realizations/f:realization[$ord+1]/text()
                            return
                            <syllab xmlns="http://fidal.parser">
<char>{$ch}</char>
<firstOrder>{$firstOrder}</firstOrder>
<order>{$ord}</order>
<transcription>{$prefixCons}</transcription>
</syllab>
else ()
}
                            {
(:                            middle:)

(:                            In the T-stem (III), if in the Perfect the subject suffix starts with a consonant, the stem changes from ta1a23a into ta1a2a3a.:)
                            if( (not($firstletterofaffix = $vowels)) and ($parsed/f:syllab[1]/f:char/text() = 'ተ')) then ($parsed/f:syllab[1],$parsed/f:syllab[2], 
                            let $secondStem := $parsed/f:syllab[3]
                            let $first := $secondStem/f:firstOrder/text()
                            let $ord :=1
                            return
<syllab xmlns="http://fidal.parser">
<char>{$morpho:letters//f:realization[.=$first]/parent::f:realizations/f:realization[$ord+1]/text()}</char>
{$secondStem/f:firstOrder}
{$secondStem/f:position}
{<order xmlns="http://fidal.parser">{$ord}</order>}
{$secondStem/f:transcription}
</syllab>
                            ) 
(:        ለብሰ                    :)
                           else if(not($firstletterofaffix = $vowels) and ($parsed/f:syllab[$secondradicalIndex]/f:order = 6)) then (
                            if($group = 'IV') then ($parsed/f:syllab[1],$parsed/f:syllab[2],$parsed/f:syllab[3])  else $parsed/f:syllab[1],
                            let $secondStem := $parsed/f:syllab[$secondradicalIndex]
                            let $first := $secondStem/f:firstOrder/text()
                            let $ord :=1
                            return
<syllab xmlns="http://fidal.parser">
<char>{$morpho:letters//f:realization[.=$first]/parent::f:realizations/f:realization[$ord+1]/text()}</char>
{$secondStem/f:firstOrder}
{$secondStem/f:position}
{<order xmlns="http://fidal.parser">{$ord}</order>}
{$secondStem/f:transcription}
</syllab>
                            ) 
                            
                            else 
                            $parsed/f:syllab[not(position()=last())]
                            
                            }
                            
                            
                            {
                            
(:                            suffix:)
                            if(count($affix) ge 1) then
                            if( $firstletterofaffix = $vowels) then (
(:                            the affix in transcription starts with vowel, so the last character is the same with modified order:)
let $ord := count($vowels[.=$firstletterofaffix]/preceding-sibling::f:vowel)
let $first := $lastSyllab/f:firstOrder/text()
return
<syllab xmlns="http://fidal.parser">
<char>{$morpho:letters//f:realization[.=$first]/parent::f:realizations/f:realization[$ord+1]/text()}</char>
{$lastSyllab/f:firstOrder}
{$lastSyllab/f:position}
{<order xmlns="http://fidal.parser">{$ord}</order>}
{$lastSyllab/f:transcription}
</syllab>,
if(string-length($affix) gt 1) 
then (let $affixAfterFirst:=substring($affix, 2) 
             let $affixAfterFirst:=replace($affixAfterFirst, 'kk', 'k')
             let $affixAfterFirst:=replace($affixAfterFirst, 'nn', 'n')
             let $affixAfterFirst:=replace($affixAfterFirst, 'tt', 't')
            return 
            morpho:transcription2chars($affixAfterFirst,$lastSyllab/f:position,$transcriptionType) ) else ()
                            ) else (
(:                            the affix starts with consonant, 
so the last character is the same modified to order 0, and further characters are to be added:)
let $first := $lastSyllab/f:firstOrder/text()
let $char := $morpho:letters//f:realization[.=$first]/parent::f:realizations/f:realization[1]/text()
            
return
<syllab xmlns="http://fidal.parser">
<char>{$char}</char>
{$lastSyllab/f:firstOrder}
{$lastSyllab/f:position}
{<order xmlns="http://fidal.parser">0</order>}
{$lastSyllab/f:transcription}
</syllab>,
let $affix:=replace($affix, 'kk', 'k')
             let $affix:=replace($affix, 'nn', 'n')
             let $affix:=replace($affix, 'tt', 't')
             return
morpho:transcription2chars($affix,$lastSyllab/f:position,$transcriptionType)
                            )
                            else (
                          let $first := $lastSyllab/f:firstOrder/text()
let $char := $morpho:letters//f:realization[.=$first]/parent::f:realizations/f:realization[1]/text()
return
<syllab xmlns="http://fidal.parser">
<char>{$char}</char>
{$lastSyllab/f:firstOrder}
{$lastSyllab/f:position}
{<order xmlns="http://fidal.parser">0</order>}
{$lastSyllab/f:transcription}
</syllab>  
                            )
                            }
                            </chars>
                            </form>
};


(:~ 
: takes a pattern and a root and produces the fidal form of the root corresponding to that pattern
: this can have 
: - small letters which are actually a fixed character
: - big letter which represent a type of character like L for laringals, S for sybilants, D for dental (?) or W or Y
: - digits which are only the position of the radical consonant
: - double digits which represent gemination
: - double big letters which represent geminated dentals or sibilants
: - going to the fidal gemination can be overlooked, so two digits can be skipped.
:)
declare function morpho:pattern2form($patt,$mainR){
let $chars:= functx:chars($mainR)
let $patt := if(matches($patt, '12')) then replace($patt, '12', '102') else $patt
let $patt := if(matches($patt, '23')) then replace($patt, '23', '203') else $patt
let $patt := if(matches($patt, '11')) then replace($patt, '11', '1') else $patt
let $patt := if(matches($patt, '22')) then replace($patt, '22', '2') else $patt
let $patt := if(matches($patt, '33')) then replace($patt, '33', '3') else $patt
let $patt := if(matches($patt, '3$')) then replace($patt, '3', '30') else $patt
let $patt := if(matches($patt, 'WW')) then replace($patt, 'WW', 'W') else $patt
let $patt := if(matches($patt, 'YY')) then replace($patt, 'YY', 'Y') else $patt
let $patt := if(matches($patt, 'YY')) then replace($patt, 'YY', 'Y') else $patt
let $patt := if(matches($patt, 'SS')) then replace($patt, 'SS', 'S') else $patt
let $patt := if(matches($patt, 'S')) then replace($patt, 'S', '1') else $patt
let $patt := if(matches($patt, 'DD')) then replace($patt, 'DD', 'D') else $patt
let $patt := if(matches($patt, 'D')) then replace($patt, 'D', '1') else $patt
let $patt := if(matches($patt, 'W2')) then replace($patt, 'W2', 'W02') else $patt
let $patt := if(matches($patt, 'W3')) then replace($patt, 'W3', 'W03') else $patt
let $patt := if(matches($patt, 'Y2')) then replace($patt, 'Y2', 'Y02') else $patt
let $patt := if(matches($patt, 'Y3')) then replace($patt, 'Y3', 'Y03') else $patt
let $patt := if(matches($patt, 'L2')) then replace($patt, 'L2', 'L02') else $patt
let $patt := if(matches($patt, 'L3')) then replace($patt, 'L3', 'L03') else $patt
let $patt := if(ends-with($patt, '\d')) then ($patt || 0) else $patt
let $analyze := analyze-string($patt, '([ʾaāǝyst]+)?([\daeiouāeǝWYLDS]{2})?([\daeiouāeǝWYLDS]{2})?([\daeiouāeǝWYLDS]{2})?(\w+)?')
let $pre := $analyze//s:group[@nr='1']/text()
let $pre := replace ($pre, 'ʾa', 'አ')
let $pre := replace ($pre, 'yā', 'ያ')
let $pre := replace ($pre, 'yǝ', 'ይ')
let $pre := replace ($pre, 's', 'ስ')
let $pre := replace ($pre, 'ta', 'ተ')
let $middle := for $group in 2 to 4 
                                  let $g := $analyze//s:group[@nr=$group]/text()
                                  let $pos:= substring($g, 1, 1)
                                  return 
                                  if($pos='') then () else 
                                  let $position := if(matches($pos, '\d')) then $pos else $group - 1 
                                  let $order := substring($g,2,1)
                                  let $tr := $morpho:letters//f:transcription[@type="BM"]
                                  let $v := $tr/f:vowel[.=$order]
                                  let $posLetter :=$chars[position()=number($position)] 
                                  let $orderVow := if($order='0') then 0 else count($v/preceding-sibling::f:vowel)
                                  let $corrLetter := $morpho:letters//f:realization[.=$posLetter]/parent::f:realizations/f:realization[$orderVow+1]/text()
                                  return $corrLetter
let $patt := $pre ||
                        string-join($middle)  ||
                         $analyze//s:group[@nr='5']/text()

let $patt := replace ($patt, 't', 'ት')
return
$patt
};

(:~ 
: takes a pattern and a root and produces the transcribed form of the root corresponding to that pattern
:
:)
declare function morpho:pattern2transcription($patt,$mainR){
let $chars:= functx:chars($mainR)
let $patt := if(matches($patt, '12')) then replace($patt, '12', '102') else $patt
let $patt := if(matches($patt, '23')) then replace($patt, '23', '203') else $patt
let $patt := if(matches($patt, '11')) then replace($patt, '11', '102') else $patt
let $patt := if(matches($patt, '22')) then replace($patt, '22', '202') else $patt
let $patt := if(matches($patt, '33')) then replace($patt, '33', '302') else $patt
let $patt := if(matches($patt, '3$')) then replace($patt, '3', '30') else $patt
let $patt := if(matches($patt, 'WW')) then replace($patt, 'WW', 'W') else $patt
let $patt := if(matches($patt, 'YY')) then replace($patt, 'YY', 'Y') else $patt
let $patt := if(matches($patt, 'LL')) then replace($patt, 'LL', 'L') else $patt
let $patt := if(matches($patt, 'SS')) then replace($patt, 'SS', 'S') else $patt
let $patt := if(matches($patt, 'DD')) then replace($patt, 'DD', 'D') else $patt
let $patt := if(matches($patt, 'W2')) then replace($patt, 'W2', 'W02') else $patt
let $patt := if(matches($patt, 'W3')) then replace($patt, 'W3', 'W03') else $patt
let $patt := if(matches($patt, 'Y2')) then replace($patt, 'Y2', 'Y02') else $patt
let $patt := if(matches($patt, 'Y3')) then replace($patt, 'Y3', 'Y03') else $patt
let $patt := if(matches($patt, 'L2')) then replace($patt, 'L2', 'L02') else $patt
let $patt := if(matches($patt, 'L3')) then replace($patt, 'L3', 'L03') else $patt
let $patt := if(ends-with($patt, '\d')) then ($patt || 0) else $patt
let $analyze := analyze-string($patt, '([ʾaāǝyst]+)?([\daeiouāeǝWYLSD]{2})?([\daeiouāeǝWYLSD]{2})?([\daeiouāeǝWYLSD]{2})?([\daeiouāeǝWYLSD]{2})?([\daeiouāeǝWYLSD]{2})?(\w+)?')
let $pre := $analyze//s:group[@nr='1']/text()
let $middle := for $group in 2 to 6 
                                  let $g := $analyze//s:group[@nr=$group]/text()
                                  let $pos:= substring($g, 1, 1)
                                  return 
                                  if($pos='') then () else 
                                  let $position := if(matches($pos, '\d')) then $pos else $group - 1 
                                  let $order := substring($g,2,1)
                                  let $vowel := if($order = '0') then () else $order
                                  let $posLetter :=$chars[position()=number($position)] 
                                  let $corrLetter := $morpho:letters//f:realization[.=$posLetter]/parent::f:realizations/preceding-sibling::f:transcription/text()
                                  return $corrLetter ||$vowel
let $patt := $pre ||
                        string-join($middle)  ||
                         $analyze//s:group[@nr='7']/text()
return
$patt
};


(:~ 
: given a generic transcription of the string input, checks it agains every affix available to find possible matches.
: the matching is simply done in this case with a regex limited at the end.
: the generic transcription is passed to the regex both with final shva if any and without
:)
declare function morpho:desinences($consVowl, $transcriptionType, $type){
let $targetpatterns := if($type='noun') then $morpho:nouns else $morpho:conjugations
let $pseudoTrans := morpho:chars2pseudotranscription($consVowl, $transcriptionType)
let $pseudoTransShort := substring($pseudoTrans, 0, string-length($pseudoTrans))
let $transcriptions := ($pseudoTrans, $pseudoTransShort)
let $countQuery := count($consVowl/f:*)
return
(for $transcription in $transcriptions
for $affix in $targetpatterns//f:affix[not(@type='pre')]
    let $countaffix:= if(string-length($affix/text()) = 1) then 0 else (let $affixChars := morpho:transcription2chars($affix/text(), 0, 'BM') return count($affixChars))
    let $cleanaffix := replace($affix, 'kk', 'k')
    let $cleanaffix := replace($cleanaffix, 'tt', 't')
    let $cleanaffix := replace($cleanaffix, 'nn', 'n')
(:matches the ending of the pseudostranscription:)
    let $regex := $cleanaffix || '$'
       return
            if (matches($transcription, $regex)) 
            then (
            <desinence  xmlns="http://fidal.parser">
                  {$affix}
                  {if($affix/ancestor::f:pronouns) then <pronouns>
                   <gender>{string($affix/ancestor::f:gender[1]/@type)}</gender>
                   <person>{string($affix/ancestor::f:person[1]/@type)}</person>
                   <number>{string($affix/ancestor::f:num[1]/@type)}</number>
                   </pronouns> else ()}
                   <gender>{string($affix/ancestor::f:gender[last()]/@type)}</gender>
                    <person>{string($affix/ancestor::f:person[last()]/@type)}</person>
                    <number>{string($affix/ancestor::f:num[last()]/@type)}</number>
                     <mode>{string($affix/ancestor::f:type[last()]/@name)}</mode>
                     <type>{string($affix/ancestor::f:group[last()]/@name)}</type>
                     <length>{$countQuery - $countaffix}</length>
                  </desinence>
             ) else ()
             
             ,
             
             for $affix in $targetpatterns//f:affix[@type='pre'][not(following-sibling::f:affix[not(@type='pre')])]
    let $cleanaffix := 'ǝ'
(:matches the ending of the pseudostranscription:)
    let $regex := $cleanaffix || '$'
    let $startregex :=  '^' || $affix/text()
       return
            if (matches($pseudoTrans, $startregex) and matches($pseudoTrans, $regex)) 
            then (
            <desinence  xmlns="http://fidal.parser">
                   <gender>{string($affix/ancestor::f:gender[last()]/@type)}</gender>
                    <person>{string($affix/ancestor::f:person[last()]/@type)}</person>
                    <number>{string($affix/ancestor::f:num[last()]/@type)}</number>
                     <mode>{string($affix/ancestor::f:type[last()]/@name)}</mode>
                     <type>{string($affix/ancestor::f:group[last()]/@name)}</type>
                     <length>{$countQuery}</length>
                  </desinence>
             ) else ())
};

(:~ 
: given a starting formula does several replacements to build candidates for each of the W, Y and L verb forms
:)
declare function morpho:schwacher($formula, $letter){

let  $formulaW1 :=if(contains($formula, '1')) then  replace($formula, '1', $letter) else $formula

let  $formulaW2 :=if(contains($formula, '2')) then  replace($formula, '2', $letter) else $formula

let  $formulaW3 :=if(contains($formula, '3')) then  replace($formula, '3', $letter) else $formula

let  $formulaGemW1 := replace($formulaW1, '2', '22')

let  $formulaGemW2 := replace($formulaW2, '1', '11')

let  $formulaGemW3 := replace($formulaW3, '2', '22')
let $gem := ($letter || $letter)
let  $formulaGem1and2W := if(contains($formulaW1, $letter)) then replace($formulaW1, $letter, $gem) else $formulaW1
return ($formulaW1, $formulaGemW2, $formulaW3, $formulaGemW1, $formulaGemW2, $formulaGemW3, $formulaGem1and2W)
};


(:~ 
: builds a series of candidate formulas to pass to the morpho:matches() and evaluate
:)
declare function morpho:formulas($chars,$query,$transcriptionType,$type){

let $consVowl :=  morpho:parseChars($chars,$query,$type)

let $possibleDesinences := morpho:desinences($consVowl, $transcriptionType, $type)
                                                    
let $formula := morpho:formula($consVowl,$transcriptionType)

(:all:)
let  $formulaGem := replace($formula, '2', '22')
let  $formulaGem1 :=if(contains($formula, '1')) then  replace($formula, '1', '11') else $formula
let  $formulaGem1and2 := if(contains($formulaGem1, '2')) then replace($formulaGem1, '2', '22') else $formulaGem1
let  $formulaGem3 := if(contains($formula, '3')) then replace($formula, '3', '33') else $formula
let $formula := if(contains($formula, '4')) then
                                    let $shortened := substring-before($formula, '4')
                                    return if(ends-with($shortened, 'ǝ')) then replace($shortened, 'ǝ', 'a') else $shortened
                                else $formula
(:verbs:)
let $formulaT := if(starts-with($formula, 'yǝ1ǝ') and $type!='noun') then ($formula => replace('1ǝ', 't')=>replace('2', '1')=>replace('3', '2')=>replace('4', '3')) else $formula
let  $formulaLongA :=  if($type='noun') then () else replace($formula, 'ā', 'a')
let  $formulaU :=  if($type='noun') then () else   replace($formula, 'u', 'a')
let  $formulaI := if($type='noun') then () else replace($formula, 'i', 'a') 
let  $formulashortW :=if(contains($formula, '1') and $type!='noun') then  replace($formula, '1', 'y') else $formula

let $schwache := if($type='noun') then (morpho:schwacher($formula, 'L'))  else  (for $letter in ('W', 'L', 'Y') return morpho:schwacher($formula, $letter))

(:nouns:)
let $formulaN := if($type='noun') then replace($formula, '4', 'nn') else ()
let $formulaLshort:= if($type='noun') then (for $s in $schwache return  substring($s, 0, string-length($s))) else ()

let $allformulas:= for $forms in (
$formulashortW,
$formula,
$formulaLshort,
$formulaLongA,
$formulaU,
$formulaI,
$formulaT,
$formulaN,
$formulaGem,
$formulaGem1,
$formulaGem1and2,
$formulaGem3, 
$schwache) return morpho:shva($forms)


let $matches := if($type='noun') then (morpho:matchesNouns($allformulas,$transcriptionType,$consVowl, $type, $possibleDesinences)) 
else morpho:matches($allformulas,$transcriptionType,$consVowl, $type, $possibleDesinences)
                                

return
    <result>
    <query>{$query}</query>
    <matches>{$matches}</matches>
    </result>
 
};


(:~ 
: givena a generically parsed string produces a flat transcription, unaware of pattern
:)
declare function morpho:chars2pseudotranscription($chars, $transcriptionType){
let $syllabs := for $char in $chars/f:* return $char/f:transcription/text() ||$morpho:letters//f:vowel[parent::f:transcription[@type=$transcriptionType]][position() = ($char/f:order + 1)]/text()
return
string-join($syllabs)
};

declare function morpho:particles($fidal){
let $pron := $morpho:pronouns//f:*[.=$fidal]
let $partic := $morpho:proclitics//f:proclitic[.=$fidal]
let $pronouns := for $cand in $pron 
                                    let $root := $cand/ancestor::f:group/f:type[@name='nominative']/f:num[@type='Singular']/f:gender[@type='Masculine']/f:full
                                   return
                                    <match xmlns="http://fidal.parser">
                                             <solution>
                                                <pos>pronoun</pos>
                                                <group>{string($cand/ancestor::f:group/@name)}</group>
                                                <type>{string($cand/ancestor::f:type/@name)}</type>
                                                <forms>
                                                <desinence>
                                                <gender>{string($cand/ancestor::f:gender/@type)}</gender>
                                            <number>{string($cand/ancestor::f:num/@type)}</number>
                                            </desinence>
                                                </forms>
                                             </solution>
                                             <roots><mainroots><root>{$root/text()}</root></mainroots></roots>
                                             </match>
let $particles := for $cand in $partic 
                                    let $root := $cand
                                    return
                                    <match xmlns="http://fidal.parser">
                                             <solution>
                                                <pos>proclitic</pos>
                                                <forms/>
                                             </solution>
                                             <roots><mainroots><root>{$root/text()}</root></mainroots></roots>
                                             </match>
 let $negative := if($fidal = $morpho:neg) then 
                                    <match xmlns="http://fidal.parser">
                                             <solution>
                                                <pos>proclitic</pos>
                                                <type>negative</type>
                                                
                                             </solution>
                                             <roots><mainroots><root>{$morpho:neg}</root></mainroots></roots>
                                             </match>
                                             else ()
 let $candidates := ($negative, $pronouns, $particles)                                            
 for $cand in $candidates return 
 <patternOk xmlns="http://fidal.parser">{morpho:checkDill($cand)}</patternOk>               
                                             
};

(:~
 : The html form with bootstrap used to build the queries in url patterns producing HTML.
 :)
declare function morpho:form(){
<form action="{$morpho:baseurl}" class="form">
<div class="form-group">
<input  class="form-control" name="query" type="search" placeholder="Search string" value="" aria-haspopup="true" role="textbox"/>
</div>
<div class="form-group">
<input  class="form-control" name="root" type="search" placeholder="Root for Paradigm or Conjugation" value="" aria-haspopup="true" role="textbox"/>
</div>
<div class="form-group">
    <label for="searches">Select Input type</label>
    <select class="form-control" id="fidal" name="fidal">
      <option selected="selected" value="true">Fidal</option>
      <option value="false">Transcription</option>
    </select>
  </div>
<div class="form-group">
    <label for="searches">Select Type of Transcription</label>
    <select class="form-control" id="transcriptionType" name="transcriptionType">
      <option selected="selected">BM</option>
      <option>EAe</option>
      <option>Voigt2013</option>
      <option>Dillmann1907</option>
      <option>Chaine1907</option>
      <option>ContiRossini1941</option>
      <option>Starinin1967</option>
    </select>
  </div>
<div class="form-check">
    <input type="checkbox" class="form-check-input" id="Dillmann" name="NoDil" value="true"/>
    <label class="form-check-label" for="Dilmann">Include results whose roots cannot be found among the ones in Online Dillmann</label>
  </div>
<div class="form-check">
    <input type="checkbox" class="form-check-input" id="fuzzy" name="fuzzy" value="true"/>
    <label class="form-check-label" for="fuzzy">Include fuzzy search on patterns</label>
  </div>
<div class="form-check">
    <input type="checkbox" class="form-check-input" id="mismatch" name="mismatch" value="true"/>
    <label class="form-check-label" for="mismatch">Include mismatches of pattern and root (patterns with W for a root which does not have w.)</label>
  </div>
<button type="submit" class="btn btn-primary">RUN</button>
</form>
};
    