�TextDocs.NewDoc     �� �"   CDocID ,    �BIER<   >        �3 � s  Oberon10.Scn.Fnt                                                                                    	            Oberon6.Scn.Fnt     Oberon10i.Scn.Fnt                           Oberon8.Scn.Fnt                                                                                                                                 	             "             �       &        �         �  Oberon12.Scn.Fnt      :               [ Network | Mail  | News | FTP | Gopher | Finger | HTTP | HyperDocs ]Gadgets Network toolsBasic	Basic networking tool.Telnet		Telnet terminal emulator.Mail
	Electronic mail.News	Usenet news.FTP	File Transfer Protocol client.Gopher	Gopher client.Finger	Finger user information.HTTP	World-Wide Web.HyperDocs	Hyperlink support for documents.Password managementPasswords for all network tools are handled uniformly by the NetSystem module.  Passwords entered with the following command are cached in memory for the rest of the Oberon session:	NetSystem.SetUser { service:username@server } ~		service = pop | telnet | ftp | slip | eamon | ... .	server = server name.	username = user name for specified service on specified server.Less secure passwords can be specified in-line:	NetSystem.SetUser { service:username:password@server } ~The password cache can be cleared with:	NetSystem.ClearUserThe \v option may be specified after SetUser for verbose output.NetSystem.SetUser may be placed in the System.InitCommands section of Oberon.Text.Integrated Access to Internet ServicesInternet services are directly accessible by using Uniform Resource Locators (URL) as a parameter to Desktops.OpenDoc, according to the following syntax:	Mail	= "mailto:" user "@" host .			= "mailserver:" user "@" host "/" subject "/" body .	Telnet	= "telnet://" [ user [ ":" passwd ] "@" ] host [ ":" port ] .	WWW	= "http://" host [ ":" port ] "/" [ path [ "?" query ] ] .	News	= "news:" ( group | msgid "@" host ) .			= "nntp:" group "/" artnr .	FTP	= "ftp://" [ user [ ":" passwd ] "@" ] host [ ":" port ] "/" [ path [ ";" type ] ] .	Gopher	= "gopher://" host [ ":" port ] [ "/" type [ selector [ "?" query ] ] ] .	Finger	= "finger://" host [ ":" port ] [ "/" request ] .�BIER�  �   .
  k
  �
  �
  #  b  �  �    J  �  �    =  |  �  �  :  b  �    7       
 
 ��    ��CCmd Desktops.ReplaceDoc Mail.Tool    7       
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
 ��    ��CCmd Desktops.ReplaceDoc HyperDocs.Tool   $   �� �     b M     b
 ��    ��C   9       
 
 ��    ��CCmd Desktops.OpenDoc NetSystem.Tool    7       
 
 ��    ��CCmd Desktops.OpenDoc Telnet.Panel    7       
 
 ��    ��CCmd Desktops.ReplaceDoc Mail.Tool    7       
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
 ��    ��CCmd Desktops.ReplaceDoc HyperDocs.Tool   "   ��      b      b
 ��    ��C  (   ��      X   .     X ��    ��C  $   ��      X       X
 ��    ��C  TextGadgets.NewControl TextGadgets.NewStyleProc  �