# flutter_local_notifications stores scheduled notifications as JSON with Gson and
# reads them back by class; shrinking would strip those classes and break reminders.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
