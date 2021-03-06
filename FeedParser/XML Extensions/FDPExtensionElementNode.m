//
//  FDPExtensionElementNode.m
//  FeedParser
//
//  Created by Kevin Ballard on 4/9/09.
//  Copyright 2009 Kevin Ballard. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "FDPExtensionElementNode.h"
#import "FPExtensionElementNode_Private.h"
#import "FDPXMLParserProtocol.h"
#import "FDPExtensionTextNode.h"

@interface FDPExtensionElementNode ()
- (void)closeTextNode;
@end

@implementation FDPExtensionElementNode
@synthesize name, qualifiedName, namespaceURI, attributes, children;

- (id)initWithElementName:(NSString *)aName namespaceURI:(NSString *)aNamespaceURI qualifiedName:(NSString *)qName
			   attributes:(NSDictionary *)attributeDict {
	if (self = [super init]) {
		name = [aName copy];
		qualifiedName = [qName copy];
		namespaceURI = [aNamespaceURI copy];
		attributes = [attributeDict copy];
		children = [[NSMutableArray alloc] init];
	}
	return self;
}

- (BOOL)isElement {
	return YES;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p <%@>>", NSStringFromClass([self class]), self, qualifiedName];
}

- (NSString *)stringValue {
	if ([children count] == 1) {
		// optimize for single child
		return [[children objectAtIndex:0] stringValue];
	} else {
		NSMutableString *stringValue = [NSMutableString string];
		for (FDPExtensionNode *child in children) {
			NSString *str = child.stringValue;
			if (str != nil) {
				[stringValue appendString:str];
			}
		}
		return stringValue;
	}
}

- (void)closeTextNode {
	FDPExtensionTextNode *child = [[FDPExtensionTextNode alloc] initWithStringValue:currentText];
	[children addObject:child];
	[child release];
	[currentText release];
	currentText = nil;
}

- (BOOL)isEqual:(id)anObject {
	if (![anObject isKindOfClass:[FDPExtensionElementNode class]]) return NO;
	FDPExtensionElementNode *other = (FDPExtensionElementNode *)anObject;
	return ((name          == other->name          || [name          isEqualToString:other->name])           &&
			(qualifiedName == other->qualifiedName || [qualifiedName isEqualToString:other->qualifiedName])  &&
			(namespaceURI  == other->namespaceURI  || [namespaceURI  isEqualToString:other->namespaceURI])   &&
			(attributes    == other->attributes    || [attributes    isEqualToDictionary:other->attributes]) &&
			(children      == other->children      || [children      isEqualToArray:other->children]));
}

- (void)dealloc {
	[name release];
	[qualifiedName release];
	[namespaceURI release];
	[attributes release];
	[children release];
	[currentText release];
	[super dealloc];
}

#pragma mark XML parser methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)aNamespaceURI
 qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if (currentText != nil) {
		[self closeTextNode];
	}
	FDPExtensionElementNode *child = [[FDPExtensionElementNode alloc] initWithElementName:elementName namespaceURI:aNamespaceURI
																		  qualifiedName:qName attributes:attributeDict];
	[child acceptParsing:parser];
	[children addObject:child];
	[child release];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if (currentText != nil) {
		[self closeTextNode];
	}
	[parser setDelegate:parentParser];
	[parentParser resumeParsing:parser fromChild:self];
	parentParser = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if (currentText == nil) currentText = [[NSMutableString alloc] init];
	[currentText appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString {
	if (currentText == nil) currentText = [[NSMutableString alloc] init];
	[currentText appendString:whitespaceString];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
	NSString *data = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
	if (data == nil) {
		[self abortParsing:parser withString:[NSString stringWithFormat:@"Non-UTF8 data found in CDATA block at line %zd", [parser lineNumber]]];
	} else {
		if (currentText == nil) currentText = [[NSMutableString alloc] init];
		[currentText appendString:data];
		[data release];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	[self abortParsing:parser withString:nil];
}

#pragma mark FDPXMLParserProtocol methods

- (void)acceptParsing:(NSXMLParser *)parser {
	parentParser = (id<FDPXMLParserProtocol>)[parser delegate];
	[parser setDelegate:self];
}

- (void)abortParsing:(NSXMLParser *)parser withString:(NSString *)description {
	id<FDPXMLParserProtocol> parent = parentParser;
	parentParser = nil;
	[currentText release];
	currentText = nil;
	[parent abortParsing:parser withString:description];
}

- (void)resumeParsing:(NSXMLParser *)parser fromChild:(id<FDPXMLParserProtocol>)child {
	// stub
}

#pragma mark -
#pragma mark Coding Support

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if (self = [super initWithCoder:aDecoder]) {
        name = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
        qualifiedName = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"qualifiedName"] copy];
        namespaceURI = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"namespaceURI"] copy];
        attributes = [[aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"attributes"] copy];
        children = [[aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [FDPExtensionNode class], nil] forKey:@"children"] mutableCopy];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:name forKey:@"name"];
	[aCoder encodeObject:qualifiedName forKey:@"qualifiedName"];
	[aCoder encodeObject:namespaceURI forKey:@"namespaceURI"];
	[aCoder encodeObject:attributes forKey:@"attributes"];
	[aCoder encodeObject:children forKey:@"children"];
}

@end
