//
//  XMPPIQ+XEP_0307.m
//  Loop
//
//  Created by Miroslav Perovic on 2/14/14.
//  Copyright (c) 2014 Appricot. All rights reserved.
//

#import "XMPPIQ+XEP_0307.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPIQ (XEP_0307)

- (NSString *)uniqueRoom {
	// <iq from='chat.shakespeare.lit'
	//     id='unique1'
	//     to='crone1@shakespeare.lit/desktop'
	//     type='result'>
	//   <unique xmlns='http://jabber.org/protocol/muc#unique'>
	//     6d9423a55f499b29ad20bf7b2bdea4f4b885ead1
	//   </unique>
	// </iq>

	NSXMLElement *unique = [self elementForName:@"unique" xmlns:XMLNS_UNIQUE_ROOM_NAMES];
	
	return [unique stringValue];
}

- (NSString *)iqId {
	// <iq from='chat.shakespeare.lit'
	//     id='unique1'
	//     to='crone1@shakespeare.lit/desktop'
	//     type='result'>
	//   <unique xmlns='http://jabber.org/protocol/muc#unique'>
	//     6d9423a55f499b29ad20bf7b2bdea4f4b885ead1
	//   </unique>
	// </iq>
	
	NSXMLNode *id = [self attributeForName:@"id"];
	
	return [id stringValue];
}

@end
