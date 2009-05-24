TODO for Localization
=====================

NEXT
----
* Views :
    * improve text fields with currency (ex: $[] should be probably be displayed []€, maybe just have a special translatable key like : "${{field}}")
    * track down missed untranslated strings
* Javascript :
    * integrate an i18n lib ? is there some good one for Prototype.js ? (I think symfony-project have something like that)
    * extract strings to use in i18n lib
    * update calculations to pass them through i18n libs to convert numbers back and forth

IDEAS
-----

It should probably be better if we can set the currency per account ?
