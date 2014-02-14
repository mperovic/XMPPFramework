//
//  XMMPUniqueRoomNames.h
//  
//
//  Created by Miroslav Perovic on 2/11/14.
//
//

#import "XMPPModule.h"
#import "XMPP.h"
#import "XMPPIQ+XEP_0307.h"

// Defined in XMPPIQ+XEP_0307.h
// #define XMLNS_UNIQUE_ROOM_NAMES		@"http://jabber.org/protocol/muc#unique"

typedef enum XMPPRoomNameErrorCode {
	XMPPRoomNameQueryTimeout,		// No response from server
	XMPPRoomNameDisconnect,			// XMPP disconnection
} XMPPRoomNameErrorCode;

@interface XMMPUniqueRoomNames : XMPPModule {
	BOOL autoClearQueryList;
}

/**
 * Whether the module should automatically clear the query list info when the client disconnects.
 *
 * As per the XEP, if there are multiple resources signed in for the user,
 * and one resource makes changes to a privacy list, all other resources are "pushed" a notification.
 * However, if our client is disconnected when another resource makes the changes,
 * then the only way we can find out about the changes are to redownload the privacy lists.
 *
 * It is recommended to clear the blocking list to assure we have the correct info.
 * However, there may be specific situations in which an xmpp client can be sure the privacy list won't change.
 *
 * The default value is YES.
 **/
@property (readwrite, assign, nonatomic) BOOL autoClearQueryList;


/**
 * Initialization methods
 **/
- (id)init;
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;

- (void)getUniqueRoomName:(XMPPJID *)jid;

/*
 * Block version
 */
- (void)getUniqueRoomName:(XMPPJID *)jid
			  withSuccess:(void (^)(NSString *uniqueName))successBlock
				  failure:(void (^)(NSError *error))failureBlock;


@end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMMPUniqueRoomNamesDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMMPUniqueRoomNamesDelegate <NSObject>
@optional

/**
 * The following delegate methods correspond almost exactly with the action methods of the class.
 * There are a few possible ways in which an action could fail:
 *
 * 1. We receive an error response from the server.
 * 2. We receive no response from the server, and the query times out.
 * 3. We get disconnected before we receive the response.
 *
 * In case number 1, the error will be an XMPPIQ of type='error'.
 *
 * In case number 2 or 3, the error will be an NSError
 * with domain=XMPPPrivacyErrorDomain and code from the XMPPRoomNameErrorCode enumeration.
 **/

- (void)xmppUniqueRoomNames:(XMMPUniqueRoomNames *)sender didReceivedRoomName:(NSString *)uniqueName;
- (void)xmppUniqueRoomNames:(XMMPUniqueRoomNames *)sender didNotReceivedRoomNameDueToError:(id)error;

@end
