xquery version "3.0";
declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;


if ($exist:path eq '') then
    <dispatch
        xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect
            url="{request:get-uri()}/"/>
    </dispatch>
    
    (: Resource paths starting with $shared are loaded from the shared-resources app :)
else
    if (contains($exist:path, "/$shared/")) then
        <dispatch
            xmlns="http://exist.sourceforge.net/NS/exist">
            <forward
                url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
                <set-header
                    name="Cache-Control"
                    value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>
        
        (: Requests for javascript libraries are resolved to the file system :)
    else
        if (contains($exist:path, "resources/"))
        then
            <dispatch
                xmlns="http://exist.sourceforge.net/NS/exist">
                <forward
                    url="{$exist:controller}/resources/{substring-after($exist:path, 'resources/')}"/>
            </dispatch>
                                                        
                                                        else
                                                            (: everything else is passed through :)
                                                            <dispatch
                                                                xmlns="http://exist.sourceforge.net/NS/exist">
                                                                <cache-control
                                                                    cache="yes"/>
                                                            </dispatch>
