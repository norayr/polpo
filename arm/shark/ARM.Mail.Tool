�TextDocs.NewDoc     �� �"   CDocID     �BIER<   >        �3 � u  Oberon10.Scn.Fnt               
                                                                     	            Oberon8.Scn.Fnt           ,   Oberon10i.Scn.Fnt             Oberon12.Scn.Fnt          7        K                     �        �       �    �  [ Network  | Mail | News | FTP | Gopher | Finger | HTTP | HyperDocs ]NetSystem.SetUser pop:<username>@<server> ~	Set mail password.Desktops.OpenDoc Mail.Panel	Open Mail panel.Mail.Mono *	Change the font of the marked.	viewer into Courier10.Mail.CutLines [width] *	Break all lines in the marked viewer	after a maximum of width characters.	The default width is 80.Mail Recipient Syntax	Recipients = RecipientsLine { RecipientsLine } .	RecipientsLine = ( "To:" | "Cc:" | "BCc:" ) Recipient { "," Recipient } .	Recipient = { Comment } MailAdr .Mail Query Syntax	Query = TQuery { "OR" TQuery } .	Query = SQuery { "&" SQuery } .	SQuery = StringQ | DateQ | TimeQ | FlagQ .	StringQ = ( "from" | "subject" | "text" | "topic" ) ( "=" | "#" ) String .	FlagQ = "read" | "unread" .	DateQ =  "date" ( "=" | "#" | "<" | ">" | ">=" | "<=") ( "today" | Date ) .	TimeQ =  "time" ( "=" | "#" | "<" | ">" | ">=" | "<=") ( "now" | Time ) .	Date = Day "." Month "." Year .	Time = Hour ":" Minute [ ":" Second ] .Using Topics	You may define a maximum of 32 different topics in Oberon.Text to	classify your mail.  See the Topic0-Topic31 in the NetSystem section.�BIER�  �  	 �  �  �  ;  z  �  �  8  b    :       
 
 ��    ��CCmd Desktops.ReplaceDoc Network.Tool    7       
 
 ��    ��CCmd Desktops.ReplaceDoc News.Tool    6       
 
 ��    ��CCmd Desktops.ReplaceDoc FTP.Tool    9       
 
 ��    ��CCmd Desktops.ReplaceDoc Gopher.Tool    9       
 
 ��    ��CCmd Desktops.ReplaceDoc Finger.Tool    7       
 
 ��    ��CCmd Desktops.ReplaceDoc HTTP.Tool    <       
 
 ��    ��CCmd Desktops.ReplaceDoc HyperDocs.Tool   $   ��      b �     b
 ��    ��C  (   ��      �  kk    �
 ��    ��C  TextGadgets.NewControl TextGadgets.NewStyleProc  �