xquery version "3.1";
declare namespace f = "http://fidal.parser";
declare namespace t = "http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";
let $q := 'ሕይወት'
return
collection('/db/apps/parser/traces/')//t:f[.=$q]