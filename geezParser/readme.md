Author: Pietro Liuzzo
Version: 0.3
Date: 13 July 2018


You can now access this prototype morphological parser at http://betamasaheft.eu/morpho

I have added a small form which lets you enter the parameters in the query.

Please keep in mind that this is supposed to be reading aid only, there should be the correct answer among the options, but it is not going to give that and only that.

This is supposed to be used in exist-db and uses range indexes configured in the collection.xconf file.

the modules folder contains the script with all functions
you can view the same module via the documentation facility of exist-db:
http://betamasaheft.eu:8080/exist/apps/fundocs/view.html?uri=http://betamasaheft.eu/parser/morpho&location=/db/apps/parser/modules/morphoparser.xql

At this extremely early stage 
- all affixes in the tables have been added 
- it is set to deal only with trilitteral radicals, nouns and some particles. 

it might work for multilitteral in terms of recognition, but I would be extremely surprised if it does. If it returns anything for paradigm and conjugation of multilitteral verbs, I do not know how because for those I do not have specific lists of patterns.   

- there are connections to the Traces data I have in TEI (at the moment only Amda Seyon) so that the initial search will also search there and provide the number of occurrences of the exact form and a link to the list of annotations, as well as, if the lemma ID is available, the link to a list of all annotations for that lemma. This new corpus view has also links which should facilitate navigation. When there will be more TEI exports, I can easily simply add them and the results will be updated. 

you can rerun your searches including the results whose pattern is not exactly matching the hypothetical root and those whose root has not been found in Dillmann, just tick the checkbox.


