//
//  XMPPIQ+XEP_0307.h
//  Loop
//
//  Created by Miroslav Perovic on 2/14/14.
//  Copyright (c) 2014 Appricot. All rights reserved.
//

#import "XMPPIQ.h"

#define XMLNS_UNIQUE_ROOM_NAMES		@"http://jabber.org/protocol/muc#unique"

@interface XMPPIQ (XEP_0307)

/**
 * Extracts the 'unique' from a server response.
 *
 * Unique Room Query Response:
 *
 * <iq from='chat.shakespeare.lit'
 *     id='unique1'
 *     to='crone1@shakespeare.lit/desktop'
 *     type='result'>
 *   <unique xmlns='http://jabber.org/protocol/muc#unique'>
 *     6d9423a55f499b29ad20bf7b2bdea4f4b885ead1
 *   </unique>
 * </iq>
 *
 * Then this method would return "6d9423a55f499b29ad20bf7b2bdea4f4b885ead1".
 *
 **/
- (NSString *)uniqueRoom;

/**
 * Extracts the 'unique' iq request id from a server response.
 *
 * Unique Room Query Response:
 *
 * <iq from='chat.shakespeare.lit'
 *     id='unique1'
 *     to='crone1@shakespeare.lit/desktop'
 *     type='result'>
 *   <unique xmlns='http://jabber.org/protocol/muc#unique'>
 *     6d9423a55f499b29ad20bf7b2bdea4f4b885ead1
 *   </unique>
 * </iq>
 *
 * Then this method would return "unique1".
 *
 **/
- (NSString *)iqId;

@end
