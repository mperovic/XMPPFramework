
//  XMMPUniqueRoomNames.m
//  
//
//  Created by Miroslav Perovic on 2/11/14.
//
//

#import "XMMPUniqueRoomNames.h"
#import "NSXMLElement+XMPP.h"
#import "NSNumber+XMPP.h"
#import "NSData+XMPP.h"
#import "XMPPLogging.h"

#define QUERY_TIMEOUT			30.0							// NSTimeInterval (double) = seconds

NSString *const XMPPRoomNameErrorDomain = @"XMPPRoomNameErrorDomain";

typedef void(^successBlock)();
typedef void(^failureBlock)(NSError *error);

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#ifdef DEBUG
	static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
#else
	static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMMPUniqueRoomNames ()  {
	NSMutableDictionary *blockingDict;
	NSMutableDictionary *pendingQueries;
}

@property (copy, nonatomic) successBlock successQuery;
@property (copy, nonatomic) failureBlock failureQuery;

@end

@interface XMPPUniqueNameQueryInfo : NSObject {
	dispatch_source_t timer;
}

@property (nonatomic, readwrite) dispatch_source_t timer;

- (void)cancel;

+ (XMPPUniqueNameQueryInfo *)query;

@end


@implementation XMMPUniqueRoomNames
@synthesize autoClearQueryList = autoClearQueryList;

- (id)init {
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue {
	if ((self = [super initWithDispatchQueue:queue])) {
		autoClearQueryList = YES;
		
		blockingDict = [[NSMutableDictionary alloc] init];
		pendingQueries = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream {
	if ([super activate:aXmppStream]) {
		// Reserved for possible future use.
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMMPUniqueRoomNames class]];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate {
	// Reserved for possible future use.
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMMPUniqueRoomNames class]];
	
	[super deactivate];
}


#pragma mark - Public Methods

- (void)getUniqueRoomName:(XMPPJID *)jid {
	NSXMLElement *getRoom = [NSXMLElement elementWithName:@"unique" xmlns:XMLNS_UNIQUE_ROOM_NAMES];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:uuid child:getRoom];
	[iq addAttributeWithName:@"from" stringValue:xmppStream.myJID.full];
	[iq addAttributeWithName:@"to" stringValue:jid.full];
	
	[self.xmppStream sendElement:iq];
	
	XMPPUniqueNameQueryInfo *qi = [XMPPUniqueNameQueryInfo query];
	[self addQueryInfo:qi withKey:uuid];
}

- (void)getUniqueRoomName:(XMPPJID *)jid
			  withSuccess:(void (^)(NSString *uniqueName))successBlock
				  failure:(void (^)(NSError *error))failureBlock {
	self.successQuery = successBlock;
	self.failureQuery = failureBlock;
	
	[self getUniqueRoomName:jid];
}

- (NSArray*)blockingList {
	if (dispatch_get_specific(moduleQueueTag)) {
		return [blockingDict allKeys];
	} else {
		__block NSArray *result;
		
		dispatch_sync(moduleQueue, ^{ @autoreleasepool {
			result = [[blockingDict allKeys] copy];
		}});
		
	    return result;
	}
}


#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"set"]) {
		if ([iq uniqueRoom]) {
			// Everything is OK
			return YES;
		}
	} else {
		// This may be a response to a query we sent
		if ([iq uniqueRoom]) {
			XMPPUniqueNameQueryInfo *queryInfo = [pendingQueries objectForKey:[iq iqId]];
			[self processQueryResponse:iq withInfo:queryInfo];
		}
		
		return YES;
	}
	
	return NO;
}

-(void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
	// If there are any pending queries,
	// they just failed due to the disconnection.
	
	for (NSString *uuid in pendingQueries) {
		[self processQueryWithFailureCode:XMPPRoomNameDisconnect];
	}
	
	// Clear the list of pending queries
	[pendingQueries removeAllObjects];
	
	// Maybe clear all stored blocking info
	if (self.autoClearQueryList) {
		[self clearQueryListInfo];
	}
}


#pragma mark - Query Processing

- (void)addQueryInfo:(XMPPUniqueNameQueryInfo *)queryInfo withKey:(NSString *)uuid {
	// Setup timer
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
	
	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
		[self queryTimeout:uuid];
	}});
	
	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, (QUERY_TIMEOUT * NSEC_PER_SEC));
	
	dispatch_source_set_timer(timer, fireTime, DISPATCH_TIME_FOREVER, 1.0);
	dispatch_resume(timer);
	
	queryInfo.timer = timer;
	
	// Add to dictionary
	[pendingQueries setObject:queryInfo forKey:uuid];
}

- (void)removeQueryInfo:(XMPPUniqueNameQueryInfo *)queryInfo withKey:(NSString *)uuid {
	// Invalidate timer
	[queryInfo cancel];
	
	// Remove from dictionary
	[pendingQueries removeObjectForKey:uuid];
}

- (void)processQueryWithFailureCode:(XMPPRoomNameErrorCode)errorCode {
	NSError *error = [NSError errorWithDomain:XMPPRoomNameErrorDomain
										 code:errorCode
									 userInfo:nil];

	if (self.failureQuery) {
		self.failureQuery(nil);
	} else {
		[multicastDelegate xmppUniqueRoomNames:self didNotReceivedRoomNameDueToError:error];
	}
}

- (void)queryTimeout:(NSString *)uuid {
	XMPPUniqueNameQueryInfo *queryInfo = [blockingDict objectForKey:uuid];
	if (queryInfo) {
		[self processQuery:queryInfo withFailureCode:XMPPRoomNameQueryTimeout];
		[self removeQueryInfo:queryInfo withKey:uuid];
	}
}

- (void)processQueryResponse:(XMPPIQ *)iq withInfo:(XMPPUniqueNameQueryInfo *)queryInfo {
	// Unique Room Query Response:
	//
	// <iq from='chat.shakespeare.lit'
	//     id='unique1'
	//     to='crone1@shakespeare.lit/desktop'
	//     type='result'>
	//   <unique xmlns='http://jabber.org/protocol/muc#unique'>
	//     6d9423a55f499b29ad20bf7b2bdea4f4b885ead1
	//   </unique>
	// </iq>
	
	if ([[iq type] isEqualToString:@"result"]) {
		NSString *uniqueRoom = [iq uniqueRoom];
		if (uniqueRoom != nil) {
			[self removeQueryInfo:queryInfo withKey:[iq iqId]];
			if (self.successQuery) {
				self.successQuery(uniqueRoom);
			} else {
				[multicastDelegate xmppUniqueRoomNames:self didReceivedRoomName:uniqueRoom];
			}
		}
	} else if ([[iq type] isEqualToString:@"error"]) {
		[self removeQueryInfo:queryInfo withKey:[iq iqId]];
		if (self.failureQuery) {
			self.failureQuery(nil);
		} else {
			[multicastDelegate xmppUniqueRoomNames:self didNotReceivedRoomNameDueToError:nil];
		}
	}
}

- (void)processQuery:(XMPPUniqueNameQueryInfo *)queryInfo withFailureCode:(XMPPRoomNameErrorCode)errorCode {
	NSError *error = [NSError errorWithDomain:XMPPRoomNameErrorDomain
										 code:errorCode
									 userInfo:nil];
	
	if (self.failureQuery) {
		self.failureQuery(nil);
	} else {
		[multicastDelegate xmppUniqueRoomNames:self didNotReceivedRoomNameDueToError:error];
	}
}


#pragma mark - Private Methods

- (void)clearQueryListInfo {
	XMPPLogTrace();
	
	if (dispatch_get_specific(moduleQueueTag)) {
		[blockingDict removeAllObjects];
	} else {
		dispatch_async(moduleQueue, ^{ @autoreleasepool {
			
			[blockingDict removeAllObjects];
		}});
	}
}

@end


#pragma mark -

@implementation XMPPUniqueNameQueryInfo

@synthesize timer;

- (id)init {
	if ((self = [super init])) {
		
	}
	
	return self;
}

- (void)cancel {
	if (timer) {
		dispatch_source_cancel(timer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
#endif
		timer = NULL;
	}
}

- (void)dealloc {
	[self cancel];
}

+ (XMPPUniqueNameQueryInfo *)query; {
	return [[XMPPUniqueNameQueryInfo alloc] init];
}

@end