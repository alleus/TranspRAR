#import "XADRARParser.h"
#import "XADRAR15Handle.h"
#import "XADRAR20Handle.h"
#import "XADRAR30Handle.h"
#import "XADRAR13CryptHandle.h"
#import "XADRAR15CryptHandle.h"
#import "XADRAR20CryptHandle.h"
#import "XADRARAESHandle.h"
#import "XADCRCHandle.h"
#import "CSFileHandle.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"
#import "XADException.h"
#import "NSDateXAD.h"
#import "Scanning.h"

#define RARFLAG_SKIP_IF_UNKNOWN 0x4000
#define RARFLAG_LONG_BLOCK    0x8000

#define MHD_VOLUME         0x0001
#define MHD_COMMENT        0x0002
#define MHD_LOCK           0x0004
#define MHD_SOLID          0x0008
#define MHD_PACK_COMMENT   0x0010
#define MHD_NEWNUMBERING   0x0010
#define MHD_AV             0x0020
#define MHD_PROTECT        0x0040
#define MHD_PASSWORD       0x0080
#define MHD_FIRSTVOLUME    0x0100
#define MHD_ENCRYPTVER     0x0200

#define LHD_SPLIT_BEFORE   0x0001
#define LHD_SPLIT_AFTER    0x0002
#define LHD_PASSWORD       0x0004
#define LHD_COMMENT        0x0008
#define LHD_SOLID          0x0010

#define LHD_WINDOWMASK     0x00e0
#define LHD_WINDOW64       0x0000
#define LHD_WINDOW128      0x0020
#define LHD_WINDOW256      0x0040
#define LHD_WINDOW512      0x0060
#define LHD_WINDOW1024     0x0080
#define LHD_WINDOW2048     0x00a0
#define LHD_WINDOW4096     0x00c0
#define LHD_DIRECTORY      0x00e0

#define LHD_LARGE          0x0100
#define LHD_UNICODE        0x0200
#define LHD_SALT           0x0400
#define LHD_VERSION        0x0800
#define LHD_EXTTIME        0x1000
#define LHD_EXTFLAGS       0x2000

#define RARMETHOD_STORE 0x30
#define RARMETHOD_FASTEST 0x31
#define RARMETHOD_FAST 0x32
#define RARMETHOD_NORMAL 0x33
#define RARMETHOD_GOOD 0x34
#define RARMETHOD_BEST 0x35

#define RAR_NOSIGNATURE 0
#define RAR_OLDSIGNATURE 1
#define RAR_SIGNATURE 2



static RARBlock ZeroBlock={0};

static inline BOOL IsZeroBlock(RARBlock block) { return block.start==0; }

static int TestSignature(const uint8_t *ptr)
{
	if(ptr[0]==0x52)
	if(ptr[1]==0x45&&ptr[2]==0x7e&&ptr[3]==0x5e) return RAR_OLDSIGNATURE;
	else if(ptr[1]==0x61&&ptr[2]==0x72&&ptr[3]==0x21&&ptr[4]==0x1a&&ptr[5]==0x07&&ptr[6]==0x00) return RAR_SIGNATURE;

	return RAR_NOSIGNATURE;
}

static const uint8_t *FindSignature(const uint8_t *ptr,int length)
{
	if(length<7) return NULL;

	for(int i=0;i<=length-7;i++) if(TestSignature(&ptr[i])) return &ptr[i];

	return NULL;
}



@implementation XADRARParser

+(int)requiredHeaderSize
{
	return 7;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO; // TODO: fix to use correct min size

	if(TestSignature(bytes)) return YES;

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if([data length]<12) return nil;
	const uint8_t *header=[data bytes];
	uint16_t flags=CSUInt16LE(&header[10]);

	// Don't bother looking for volumes if it the volume bit is not set.
	if(!(flags&1)) return nil;

	// Check the old/new naming bit.
	if(flags&0x10)
	{
		// New naming scheme. Find the last number in the name, and look for other files
		// with the same number of digits in the same location.
		NSArray *matches;
		if((matches=[name substringsCapturedByPattern:@"^(.*[^0-9])([0-9]+)(.*)\\.rar$" options:REG_ICASE]))
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@[0-9]{%d}%@.rar$",
			[[matches objectAtIndex:1] escapedPattern],
			[(NSString *)[matches objectAtIndex:2] length],
			[[matches objectAtIndex:3] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"rar"];
	}

	// Old naming scheme. Just look for rar/r01/s01 files.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"rar"];
	}

	return nil;
}



-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		keys=nil;
	}
	return self;
}

-(void)dealloc
{
	[keys release];
	[super dealloc];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	uint8_t buf[7];
	[handle readBytes:7 toBuffer:buf];	

	if(TestSignature(buf)==RAR_OLDSIGNATURE)
	{
		[XADException raiseNotSupportedException];
		// [fh skipBytes:-3];
		// TODO: handle old RARs.
	}

	archiveflags=0;
	lastcompressed=nil;

	RARBlock block;
	for(;;)
	{
		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) [XADException raiseIllegalDataException];
		if(block.type==0x74) break;
		[self skipBlock:block];
	}

	while(!IsZeroBlock(block)&&[self shouldKeepParsing])
	{
		//NSAutoreleasePool *pool=[NSAutoreleasePool new];
		block=[self readFileHeaderWithBlock:block];
		//[pool release];
	}
}

-(RARBlock)readFileHeaderWithBlock:(RARBlock)block
{
	if(block.flags&LHD_SPLIT_BEFORE) return [self findNextFileHeaderAfterBlock:block];

	CSHandle *fh=block.fh;
	XADSkipHandle *skip=[self skipHandle];

	int flags=block.flags;
	off_t skipstart=[skip skipOffsetForActualOffset:block.datastart];

	off_t size=[fh readUInt32LE];
	int os=[fh readUInt8];
	uint32_t crc=[fh readUInt32LE];
	uint32_t dostime=[fh readUInt32LE];
	int version=[fh readUInt8];
	int method=[fh readUInt8];
	int namelength=[fh readUInt16LE];
	uint32_t attrs=[fh readUInt32LE];

	if(block.flags&LHD_LARGE)
	{
		block.datasize+=(off_t)[fh readUInt32LE]<<32;
		size+=(off_t)[fh readUInt32LE]<<32;
	}

	NSData *namedata=[fh readDataOfLength:namelength];

	NSData *salt=nil;
	if(block.flags&LHD_SALT) salt=[fh readDataOfLength:8];

	off_t datasize=block.datasize;

	off_t lastpos=block.datastart+block.datasize;
	BOOL last=(block.flags&LHD_SPLIT_AFTER)?NO:YES;
	BOOL partial=NO;

	for(;;)
	{
		[self skipBlock:block];

		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) break;

		fh=block.fh;

		if(block.type==0x74) // file header
		{
			if(last) break;
			else if(!(block.flags&LHD_SPLIT_BEFORE)) { partial=YES; break; }

			[fh skipBytes:5];
			crc=[fh readUInt32LE];
			[fh skipBytes:6];
			int namelength=[fh readUInt16LE];
			[fh skipBytes:4];

			if(block.flags&LHD_LARGE)
			{
				block.datasize+=(off_t)[fh readUInt32LE]<<32;
				[fh skipBytes:4];
			}

			NSData *currnamedata=[fh readDataOfLength:namelength];

			if(![namedata isEqual:currnamedata])
			{ // Name doesn't match, skip back to header and give up.
				[fh seekToFileOffset:block.start];
				block=[self readBlockHeaderLevel2];
				partial=YES;
				break;
			}

			datasize+=block.datasize;

			[skip addSkipFrom:lastpos to:block.datastart];
			lastpos=block.datastart+block.datasize;

			if(!(block.flags&LHD_SPLIT_AFTER)) last=YES;
		}
		else if(block.type==0x7a) // newsub header
		{
			// TODO: parse new comments
			//NSLog(@"newsub");
		}
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self parseNameData:namedata flags:flags],XADFileNameKey,
		[NSNumber numberWithLongLong:size],XADFileSizeKey,
		[NSNumber numberWithLongLong:datasize],XADCompressedSizeKey,
		[NSDate XADDateWithMSDOSDateTime:dostime],XADLastModificationDateKey,

		[NSNumber numberWithInt:flags],@"RARFlags",
		[NSNumber numberWithInt:version],@"RARCompressionVersion",
		[NSNumber numberWithInt:method],@"RARCompressionMethod",
		[NSNumber numberWithUnsignedInt:crc],@"RARCRC32",
		[NSNumber numberWithInt:os],@"RAROS",
		[NSNumber numberWithUnsignedInt:attrs],@"RARAttributes",
	nil];

	if(salt) [dict setObject:salt forKey:@"RARSalt"];

	if(partial) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];

	if(flags&LHD_PASSWORD) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
	if((flags&LHD_WINDOWMASK)==LHD_DIRECTORY) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	if(version==15 && os==0 && (attrs&0x10)) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	NSString *osname=nil;
	switch(os)
	{
		case 0: osname=@"MS-DOS"; break;
		case 1: osname=@"OS/2"; break;
		case 2: osname=@"Win32"; break;
		case 3: osname=@"Unix"; break;
	}
	if(osname) [dict setObject:[self XADStringWithString:osname] forKey:@"RAROSName"];

	switch(os)
	{
		case 0: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADDOSFileAttributesKey]; break;
		case 2: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADWindowsFileAttributesKey]; break;
		case 3: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADPosixPermissionsKey]; break;
	}

	NSString *methodname=nil;
	switch(method)
	{
		case 0x30: methodname=@"None"; break;
		case 0x31: methodname=[NSString stringWithFormat:@"Fastest v%d.%d",version/10,version%10]; break;
		case 0x32: methodname=[NSString stringWithFormat:@"Fast v%d.%d",version/10,version%10]; break;
		case 0x33: methodname=[NSString stringWithFormat:@"Normal v%d.%d",version/10,version%10]; break;
		case 0x34: methodname=[NSString stringWithFormat:@"Good v%d.%d",version/10,version%10]; break;
		case 0x35: methodname=[NSString stringWithFormat:@"Best v%d.%d",version/10,version%10]; break;
	}
	if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

	if(method==0x30)
	{
		[dict setObject:[NSNumber numberWithLongLong:skipstart] forKey:XADSkipOffsetKey];
		[dict setObject:[NSNumber numberWithLongLong:datasize] forKey:XADSkipLengthKey];
	}
	else
	{
		BOOL solid;
		if(version<20) solid=(archiveflags&MHD_SOLID)&&lastcompressed;
		else solid=(flags&LHD_SOLID)!=0;

		if(solid&&!lastcompressed)
		{
			[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
			return block;
		}

		NSMutableArray *parts;

		if(solid)
		{
			parts=[lastcompressed objectForKey:XADSolidObjectKey];
			NSNumber *lastoffs=[lastcompressed objectForKey:XADSolidOffsetKey];
			NSNumber *lastlen=[lastcompressed objectForKey:XADSolidLengthKey];
			off_t newoffs=[lastoffs longLongValue]+[lastlen longLongValue];
			[dict setObject:[NSNumber numberWithLongLong:newoffs] forKey:XADSolidOffsetKey];
		}
		else
		{
			parts=[NSMutableArray array];
			[dict setObject:[NSNumber numberWithLongLong:0] forKey:XADSolidOffsetKey];
		}
 
		[parts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:skipstart],@"SkipOffset",
			[NSNumber numberWithLongLong:datasize],@"InputLength",
			[NSNumber numberWithLongLong:size],@"OutputLength",
			[NSNumber numberWithInt:version],@"Version",
			[NSNumber numberWithBool:(flags&LHD_PASSWORD)?YES:NO],@"Encrypted",
			salt,@"Salt", // ends the list if nil
		nil]];
		[dict setObject:parts forKey:XADSolidObjectKey];
		[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADSolidLengthKey];

		lastcompressed=dict;
	}

	[self addEntryWithDictionary:dict retainPosition:YES];

	return block;
}

-(RARBlock)findNextFileHeaderAfterBlock:(RARBlock)block
{
	for(;;)
	{
		[self skipBlock:block];
		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) return ZeroBlock;

		if(block.type==0x74) return block;
	}
}



-(RARBlock)readBlockHeaderLevel2
{
	for(;;)
	{
		RARBlock block=[self readBlockHeaderLevel1];

		if(block.type==0x72) // file marker header
		{
			[self skipBlock:block];
		}
		else if(block.type==0x73) // archive header
		{
			CSHandle *fh=block.fh;

			archiveflags=block.flags;

			[fh skipBytes:6]; // Skip signature stuff

			if(block.flags&MHD_ENCRYPTVER)
			{
				encryptversion=[fh readUInt8];
			}
			else encryptversion=0; // ?

			if(block.flags&MHD_COMMENT)
			{
				RARBlock commentblock=[self readBlockHeaderLevel1];
				[self readCommentBlock:commentblock];
			}

			[self skipBlock:block];
		}
		//else if(block.type==0x7a) // newsub header
		//{
		//}
		else if(block.type==0x7b) // end header
		{
			archiveflags=0;

			[self skipBlock:block];

			CSHandle *handle=[self handle];
			if([handle respondsToSelector:@selector(currentHandle)]) handle=[(id)handle currentHandle];
			if([handle offsetInFile]!=0) [handle seekToEndOfFile];
		}
		else
		{
			return block;
		}
	}
}



-(RARBlock)readBlockHeaderLevel1
{
	CSHandle *fh=[self handle];

	RARBlock block;
	block.start=[[self handle] offsetInFile];

	if(archiveflags&MHD_PASSWORD)
	{
		NSData *salt=[fh readDataOfLength:8];
		fh=[[[XADRARAESHandle alloc] initWithHandle:fh key:[self keyForSalt:salt]] autorelease];
	}

	block.fh=fh;

	@try
	{
		block.crc=[fh readUInt16LE];
		block.type=[fh readUInt8];
		block.flags=[fh readUInt16LE];
		block.headersize=[fh readUInt16LE];
	}
	@catch(id e) { return ZeroBlock; }

	// Removed CRC checking because RAR uses it completely inconsitently
/*	if(block.crc!=0x6152||block.type!=0x72||block.flags!=0x1a21||block.headersize!=7)
	{
		off_t pos=[fh offsetInFile];
		uint32_t crc=0xffffffff;
		@try
		{
			crc=XADCRC(crc,block.type,XADCRCTable_edb88320);
			crc=XADCRC(crc,(block.flags&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,((block.flags>>8)&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,(block.headersize&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,((block.headersize>>8)&0xff),XADCRCTable_edb88320);
			for(int i=7;i<block.headersize;i++)
			{
NSLog(@"%04x %04x %s",~crc&0xffff,block.crc,(~crc&0xffff)==block.crc?"<-------":"");
				crc=XADCRC(crc,[fh readUInt8],XADCRCTable_edb88320);
			}
		}
		@catch(id e) {}

		if((~crc&0xffff)!=block.crc)
		{
			if(archiveflags&MHD_PASSWORD) [XADException raisePasswordException];
			else [XADException raiseIllegalDataException];
		}

		[fh seekToFileOffset:pos];
	}*/

	if(block.flags&RARFLAG_LONG_BLOCK) block.datasize=[fh readUInt32LE];
	else block.datasize=0;

	if(archiveflags&MHD_PASSWORD) block.datastart=block.start+((block.headersize+15)&~15)+8;
	else block.datastart=block.start+block.headersize;

	//NSLog(@"block:%x flags:%x headsize:%d datasize:%qu ",block.type,block.flags,block.headersize,block.datasize);

	return block;
}

-(void)skipBlock:(RARBlock)block
{
	[[self handle] seekToFileOffset:block.datastart+block.datasize];
}

-(void)readCommentBlock:(RARBlock)block
{
	CSHandle *fh=block.fh;

	int commentsize=[fh readUInt16LE];
	int version=[fh readUInt8];
	/*int method=*/[fh readUInt8];
	/*int crc=*/[fh readUInt16LE];

	CSHandle *handle=[self handleWithVersion:version skipOffset:[[self skipHandle] offsetInFile]
	inputLength:block.headersize-13 outputLength:commentsize encrypted:NO salt:nil];

	NSData *comment=[handle readDataOfLength:commentsize];
	[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
}

-(XADPath *)parseNameData:(NSData *)data flags:(int)flags
{
	if(flags&LHD_UNICODE)
	{
		int length=[data length];
		const uint8_t *bytes=[data bytes];

		int n=0;
		while(n<length&&bytes[n]) n++;

		if(n==length) return [self XADPathWithData:data encodingName:XADUTF8StringEncodingName separators:XADWindowsPathSeparator];

		int num=length-n-1;
		if(num<=1) return [self XADPathWithCString:(const char *)bytes separators:XADWindowsPathSeparator];

		CSMemoryHandle *fh=[CSMemoryHandle memoryHandleForReadingBuffer:bytes+n+1 length:num];
		NSMutableString *str=[NSMutableString string];

		@try
		{
			int highbyte=[fh readUInt8]<<8;
			int flagbyte,flagbits=0;

			while(![fh atEndOfFile])
			{
				if(flagbits==0)
				{
					flagbyte=[fh readUInt8];
					flagbits=8;
				}

				flagbits-=2;
				switch((flagbyte>>flagbits)&3)
				{
					case 0: [str appendFormat:@"%C",[fh readUInt8]]; break;
					case 1: [str appendFormat:@"%C",highbyte+[fh readUInt8]]; break;
					case 2: [str appendFormat:@"%C",[fh readUInt16LE]]; break;
					case 3:
					{
						int len=[fh readUInt8];
						if(len&0x80)
						{
							int correction=[fh readUInt8];
							for(int i=0;i<(len&0x7f)+2;i++)
							[str appendFormat:@"%C",highbyte+(bytes[[str length]]+correction&0xff)];
						}
						else for(int i=0;i<(len&0x7f)+2;i++)
						[str appendFormat:@"%C",bytes[[str length]]];
					}
					break;
				}
			}
		}
		@catch(id e) {}

		// TODO: avoid re-encoding
		return [self XADPathWithData:[str dataUsingEncoding:NSUTF8StringEncoding]
		encodingName:XADUTF8StringEncodingName separators:XADWindowsPathSeparator];
	}
	else return [self XADPathWithData:data separators:XADWindowsPathSeparator];
}





-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle;
	if([[dict objectForKey:@"RARCompressionMethod"] intValue]==0x30)
	{
		off_t skipoffs=[[dict objectForKey:XADSkipOffsetKey] longLongValue];
		off_t skiplength=[[dict objectForKey:XADSkipLengthKey] longLongValue];
		off_t filesize=[[dict objectForKey:XADFileSizeKey] longLongValue];
		BOOL encrypted=[[dict objectForKey:XADIsEncryptedKey] boolValue];
		int cryptver=[[dict objectForKey:@"RARCompressionVersion"] intValue];

		handle=[self dataHandleFromSkipOffset:skipoffs length:skiplength
		encrypted:encrypted cryptoVersion:cryptver salt:[dict objectForKey:@"RARSalt"]];

		if(skiplength!=filesize) handle=[handle nonCopiedSubHandleOfLength:filesize];
	}
	else
	{
		// Avoid 0-length files because they make trouble in solid streams.
		off_t length=[[dict objectForKey:XADSolidLengthKey] longLongValue];
		if(length==0) handle=[self zeroLengthHandleWithChecksum:NO];
		else handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"RARCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
{
	int version=[[[obj objectAtIndex:0] objectForKey:@"Version"] intValue];

	switch(version)
	{
		case 15:
			return [[[XADRAR15Handle alloc] initWithRARParser:self parts:obj] autorelease];

		case 20:
		case 26:
			return [[[XADRAR20Handle alloc] initWithRARParser:self parts:obj] autorelease];

		case 29:
		case 36:
			return [[[XADRAR30Handle alloc] initWithRARParser:self parts:obj] autorelease];

		default:
			return nil;
	}
}

-(CSHandle *)handleWithVersion:(int)version skipOffset:(off_t)skipoffset
inputLength:(off_t)inputlength outputLength:(off_t)outputlength encrypted:(BOOL)encrypted
salt:(NSData *)salt
{
	return [self handleForSolidStreamWithObject:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithLongLong:skipoffset],@"SkipOffset",
		[NSNumber numberWithLongLong:inputlength],@"InputLength",
		[NSNumber numberWithLongLong:outputlength],@"OutputLength",
		[NSNumber numberWithInt:version],@"Version",
		[NSNumber numberWithBool:encrypted],@"Encrypted",
		salt,@"Salt", // ends the list if nil
	nil]] wantChecksum:NO];
}

-(CSHandle *)dataHandleFromSkipOffset:(off_t)offs length:(off_t)length
encrypted:(BOOL)encrypted cryptoVersion:(int)version salt:(NSData *)salt
{
	CSHandle *fh=[[self skipHandle] nonCopiedSubHandleFrom:offs length:length];

	if(encrypted)
	{
		switch(version)
		{
			case 13: return [[[XADRAR13CryptHandle alloc] initWithHandle:fh
			password:[self encodedPassword]] autorelease];

			case 15: return [[[XADRAR15CryptHandle alloc] initWithHandle:fh
			password:[self encodedPassword]] autorelease];

			case 20: return [[[XADRAR20CryptHandle alloc] initWithHandle:fh
			password:[self encodedPassword]] autorelease];

			default:
			return [[[XADRARAESHandle alloc] initWithHandle:fh key:[self keyForSalt:salt]] autorelease];
		}
	}
	else return fh;
}

-(NSData *)keyForSalt:(NSData *)salt
{
	if(!keys) keys=[NSMutableDictionary new];

	NSData *key=[keys objectForKey:salt];
	if(key) return key;

	key=[XADRARAESHandle keyForPassword:[self password] salt:salt brokenHash:encryptversion<36];
	[keys setObject:key forKey:salt];
	return key;
}

-(CSInputBuffer *)inputBufferForNextPart:(int *)part parts:(NSArray *)parts length:(off_t *)partlength;
{
	if(*part>=[parts count]) [XADException raiseExceptionWithXADError:XADInputError]; // TODO: better error
	NSDictionary *dict=[parts objectAtIndex:(*part)++];

	if(partlength) *partlength=[[dict objectForKey:@"OutputLength"] longLongValue];

	CSHandle *handle=[self
	dataHandleFromSkipOffset:[[dict objectForKey:@"SkipOffset"] longLongValue]
	length:[[dict objectForKey:@"InputLength"] longLongValue]
	encrypted:[[dict objectForKey:@"Encrypted"] longLongValue]
	cryptoVersion:[[dict objectForKey:@"Version"] intValue]
	salt:[dict objectForKey:@"Salt"]];

	return CSInputBufferAlloc(handle,16384);
}

-(NSString *)formatName
{
	return @"RAR";
}

@end





@implementation XADEmbeddedRARParser

+(int)requiredHeaderSize
{
	return 0x80000;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	const uint8_t *header=FindSignature(bytes,length);
	if(header)
	{
		[props setObject:[NSNumber numberWithLongLong:header-bytes] forKey:@"RAREmbedOffset"];
		return YES;
	}

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	const uint8_t *header=FindSignature(bytes,length);
	if(!header) return nil; // Shouldn't happen

	uint16_t flags=CSUInt16LE(&header[10]);

	// Don't bother looking for volumes if it the volume bit is not set.
	if(!(flags&0x01)) return nil;

	// Don't bother looking for volumes if it the new naming bit is not set.
	if(!(flags&0x10)) return nil;

	// New naming scheme. Find the last number in the name, and look for other files
	// with the same number of digits in the same location.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*[^0-9])([0-9]+)(.*)\\.exe$" options:REG_ICASE]))
	return [self scanForVolumesWithFilename:name
	regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@[0-9]{%d}%@.(rar|exe)$",
		[[matches objectAtIndex:1] escapedPattern],
		[(NSString *)[matches objectAtIndex:2] length],
		[[matches objectAtIndex:3] escapedPattern]] options:REG_ICASE]
	firstFileExtension:@"exe"];

	return nil;
}

-(void)parse
{
	off_t offs=[[[self properties] objectForKey:@"RAREmbedOffset"] longLongValue];
	[[self handle] seekToFileOffset:offs];

	[super parse];
}

-(NSString *)formatName
{
	return @"Embedded RAR";
}

@end
