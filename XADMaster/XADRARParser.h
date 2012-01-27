#import "XADArchiveParser.h"
#import "CSInputBuffer.h"

typedef struct RARBlock
{
	int crc,type,flags;
	int headersize;
	off_t datasize;
	off_t start,datastart;
	CSHandle *fh;
} RARBlock;

@interface XADRARParser:XADArchiveParser
{
	int archiveflags,encryptversion;

	NSMutableDictionary *lastcompressed;
	NSMutableDictionary *keys;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(RARBlock)readFileHeaderWithBlock:(RARBlock)block;
-(RARBlock)findNextFileHeaderAfterBlock:(RARBlock)block;

-(RARBlock)readBlockHeaderLevel2;

-(RARBlock)readBlockHeaderLevel1;
-(void)skipBlock:(RARBlock)block;

-(void)readCommentBlock:(RARBlock)block;
-(XADPath *)parseNameData:(NSData *)data flags:(int)flags;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(CSHandle *)handleWithVersion:(int)version skipOffset:(off_t)skipoffset
inputLength:(off_t)inputlength outputLength:(off_t)outputlength encrypted:(BOOL)encrypted
salt:(NSData *)salt;

-(CSHandle *)dataHandleFromSkipOffset:(off_t)offs length:(off_t)length
encrypted:(BOOL)encrypted cryptoVersion:(int)version salt:(NSData *)salt;
-(NSData *)keyForSalt:(NSData *)salt;

-(CSInputBuffer *)inputBufferForNextPart:(int *)part parts:(NSArray *)parts length:(off_t *)partlength;

-(NSString *)formatName;

@end


@interface XADEmbeddedRARParser:XADRARParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(void)parse;
-(NSString *)formatName;

@end
