// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:_fe_analyzer_shared/src/macros/api.dart';
import 'package:_fe_analyzer_shared/src/macros/executor.dart';
import 'package:_fe_analyzer_shared/src/macros/executor/introspection_impls.dart';
import 'package:_fe_analyzer_shared/src/macros/executor/remote_instance.dart';
import 'package:_fe_analyzer_shared/src/macros/executor/serialization.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  for (var mode in [
    SerializationMode.jsonClient,
    SerializationMode.jsonServer,
    SerializationMode.byteDataClient,
    SerializationMode.byteDataServer,
  ]) {
    test('$mode can serialize and deserialize basic data', () {
      withSerializationMode(mode, () {
        var serializer = serializerFactory();
        serializer
          ..addInt(0)
          ..addInt(1)
          ..addInt(0xff)
          ..addInt(0xffff)
          ..addInt(0xffffffff)
          ..addInt(0xffffffffffffffff)
          ..addInt(-1)
          ..addInt(-0x80)
          ..addInt(-0x8000)
          ..addInt(-0x80000000)
          ..addInt(-0x8000000000000000)
          ..addNullableInt(null)
          ..addString('hello')
          ..addString('€') // Requires a two byte string
          ..addString('𐐷') // Requires two, 16 bit code units
          ..addNullableString(null)
          ..startList()
          ..addBool(true)
          ..startList()
          ..addNull()
          ..endList()
          ..addNullableBool(null)
          ..endList()
          ..addDouble(1.0)
          ..startList()
          ..endList();
        var deserializer = deserializerFactory(serializer.result);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 0);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 1);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 0xff);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 0xffff);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 0xffffffff);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), 0xffffffffffffffff);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), -1);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), -0x80);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), -0x8000);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), -0x80000000);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectInt(), -0x8000000000000000);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectNullableInt(), null);
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectString(), 'hello');
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectString(), '€');
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectString(), '𐐷');
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectNullableString(), null);
        expect(deserializer.moveNext(), true);

        deserializer.expectList();
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectBool(), true);
        expect(deserializer.moveNext(), true);

        deserializer.expectList();
        expect(deserializer.moveNext(), true);
        expect(deserializer.checkNull(), true);
        expect(deserializer.moveNext(), false);

        expect(deserializer.moveNext(), true);
        expect(deserializer.expectNullableBool(), null);
        expect(deserializer.moveNext(), false);

        // Have to move the parent again to advance it past the list entry.
        expect(deserializer.moveNext(), true);
        expect(deserializer.expectDouble(), 1.0);
        expect(deserializer.moveNext(), true);

        deserializer.expectList();
        expect(deserializer.moveNext(), false);

        expect(deserializer.moveNext(), false);
      });
    });
  }

  for (var mode in [
    SerializationMode.byteDataServer,
    SerializationMode.jsonServer
  ]) {
    test('remote instances in $mode', () async {
      var string = NamedTypeAnnotationImpl(
          id: RemoteInstance.uniqueId,
          isNullable: false,
          identifier:
              IdentifierImpl(id: RemoteInstance.uniqueId, name: 'String'),
          typeArguments: const []);
      var foo = NamedTypeAnnotationImpl(
          id: RemoteInstance.uniqueId,
          isNullable: false,
          identifier: IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Foo'),
          typeArguments: [string]);

      withSerializationMode(mode, () {
        var serializer = serializerFactory();
        foo.serialize(serializer);
        var response = roundTrip(serializer.result);
        var deserializer = deserializerFactory(response);
        var instance = RemoteInstance.deserialize(deserializer);
        expect(instance, foo);
      });
    });
  }

  group('declarations', () {
    final barType = NamedTypeAnnotationImpl(
        id: RemoteInstance.uniqueId,
        isNullable: false,
        identifier: IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Bar'),
        typeArguments: []);
    final fooType = NamedTypeAnnotationImpl(
        id: RemoteInstance.uniqueId,
        isNullable: true,
        identifier: IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Foo'),
        typeArguments: [barType]);

    for (var mode in [
      SerializationMode.byteDataServer,
      SerializationMode.jsonServer
    ]) {
      group('with mode $mode', () {
        test('NamedTypeAnnotation', () {
          expectSerializationEquality<TypeAnnotationImpl>(
              fooType, mode, RemoteInstance.deserialize);
        });

        final fooNamedParam = ParameterDeclarationImpl(
            id: RemoteInstance.uniqueId,
            isNamed: true,
            isRequired: true,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'foo'),
            type: fooType);
        final fooNamedFunctionTypeParam = FunctionTypeParameterImpl(
            id: RemoteInstance.uniqueId,
            isNamed: true,
            isRequired: true,
            name: 'foo',
            type: fooType);

        final barPositionalParam = ParameterDeclarationImpl(
            id: RemoteInstance.uniqueId,
            isNamed: false,
            isRequired: false,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'bar'),
            type: barType);
        final barPositionalFunctionTypeParam = FunctionTypeParameterImpl(
            id: RemoteInstance.uniqueId,
            isNamed: true,
            isRequired: true,
            name: 'bar',
            type: fooType);

        final unnamedFunctionTypeParam = FunctionTypeParameterImpl(
            id: RemoteInstance.uniqueId,
            isNamed: true,
            isRequired: true,
            name: null,
            type: fooType);

        final zapTypeParam = TypeParameterDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Zap'),
            bound: barType);

        // Transitively tests `TypeParameterDeclaration` and
        // `ParameterDeclaration`.
        test('FunctionTypeAnnotation', () {
          var functionType = FunctionTypeAnnotationImpl(
            id: RemoteInstance.uniqueId,
            isNullable: true,
            namedParameters: [
              fooNamedFunctionTypeParam,
              unnamedFunctionTypeParam
            ],
            positionalParameters: [barPositionalFunctionTypeParam],
            returnType: fooType,
            typeParameters: [zapTypeParam],
          );
          expectSerializationEquality<TypeAnnotationImpl>(
              functionType, mode, RemoteInstance.deserialize);
        });

        test('FunctionDeclaration', () {
          var function = FunctionDeclarationImpl(
              id: RemoteInstance.uniqueId,
              identifier:
                  IdentifierImpl(id: RemoteInstance.uniqueId, name: 'name'),
              isAbstract: true,
              isExternal: false,
              isGetter: true,
              isOperator: false,
              isSetter: false,
              namedParameters: [],
              positionalParameters: [],
              returnType: fooType,
              typeParameters: []);
          expectSerializationEquality<DeclarationImpl>(
              function, mode, RemoteInstance.deserialize);
        });

        test('MethodDeclaration', () {
          var method = MethodDeclarationImpl(
              id: RemoteInstance.uniqueId,
              identifier:
                  IdentifierImpl(id: RemoteInstance.uniqueId, name: 'zorp'),
              isAbstract: false,
              isExternal: false,
              isGetter: false,
              isOperator: false,
              isSetter: true,
              namedParameters: [fooNamedParam],
              positionalParameters: [barPositionalParam],
              returnType: fooType,
              typeParameters: [zapTypeParam],
              definingType: fooType.identifier,
              isStatic: false);
          expectSerializationEquality<DeclarationImpl>(
              method, mode, RemoteInstance.deserialize);
        });

        test('ConstructorDeclaration', () {
          var constructor = ConstructorDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'new'),
            isAbstract: false,
            isExternal: false,
            isGetter: false,
            isOperator: true,
            isSetter: false,
            namedParameters: [fooNamedParam],
            positionalParameters: [barPositionalParam],
            returnType: fooType,
            typeParameters: [zapTypeParam],
            definingType: fooType.identifier,
            isFactory: true,
          );
          expectSerializationEquality<DeclarationImpl>(
              constructor, mode, RemoteInstance.deserialize);
        });

        test('VariableDeclaration', () {
          var bar = VariableDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'bar'),
            isExternal: true,
            isFinal: false,
            isLate: true,
            type: barType,
          );
          expectSerializationEquality<DeclarationImpl>(
              bar, mode, RemoteInstance.deserialize);
        });

        test('FieldDeclaration', () {
          var bar = FieldDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'bar'),
            isExternal: false,
            isFinal: true,
            isLate: false,
            type: barType,
            definingType: fooType.identifier,
            isStatic: false,
          );
          expectSerializationEquality<DeclarationImpl>(
              bar, mode, RemoteInstance.deserialize);
        });

        var objectType = NamedTypeAnnotationImpl(
          id: RemoteInstance.uniqueId,
          identifier:
              IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Object'),
          isNullable: false,
          typeArguments: [],
        );
        var serializableType = NamedTypeAnnotationImpl(
          id: RemoteInstance.uniqueId,
          identifier:
              IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Serializable'),
          isNullable: false,
          typeArguments: [],
        );

        test('ClassDeclaration', () {
          for (var boolValue in [true, false]) {
            var fooClass = ClassDeclarationImpl(
              id: RemoteInstance.uniqueId,
              identifier:
                  IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Foo'),
              interfaces: [barType],
              hasAbstract: boolValue,
              hasBase: boolValue,
              hasExternal: boolValue,
              hasFinal: boolValue,
              hasInterface: boolValue,
              hasMixin: boolValue,
              hasSealed: boolValue,
              mixins: [serializableType],
              superclass: objectType,
              typeParameters: [zapTypeParam],
            );
            expectSerializationEquality<DeclarationImpl>(
                fooClass, mode, RemoteInstance.deserialize);
          }
        });

        test('EnumDeclaration', () {
          var fooEnum = EnumDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'MyEnum'),
            interfaces: [barType],
            mixins: [serializableType],
            typeParameters: [zapTypeParam],
          );
          expectSerializationEquality<DeclarationImpl>(
              fooEnum, mode, RemoteInstance.deserialize);
        });

        test('EnumValueDeclaration', () {
          var entry = EnumValueDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier: IdentifierImpl(id: RemoteInstance.uniqueId, name: 'a'),
            definingEnum:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'MyEnum'),
          );
          expectSerializationEquality<DeclarationImpl>(
              entry, mode, RemoteInstance.deserialize);
        });

        test('MixinDeclaration', () {
          for (var base in [true, false]) {
            var mixin = MixinDeclarationImpl(
              id: RemoteInstance.uniqueId,
              identifier:
                  IdentifierImpl(id: RemoteInstance.uniqueId, name: 'MyMixin'),
              hasBase: base,
              interfaces: [barType],
              superclassConstraints: [serializableType],
              typeParameters: [zapTypeParam],
            );
            expectSerializationEquality<DeclarationImpl>(
                mixin, mode, RemoteInstance.deserialize);
          }
        });

        test('TypeAliasDeclaration', () {
          var typeAlias = TypeAliasDeclarationImpl(
            id: RemoteInstance.uniqueId,
            identifier:
                IdentifierImpl(id: RemoteInstance.uniqueId, name: 'FooOfBar'),
            typeParameters: [zapTypeParam],
            aliasedType: NamedTypeAnnotationImpl(
                id: RemoteInstance.uniqueId,
                isNullable: false,
                identifier:
                    IdentifierImpl(id: RemoteInstance.uniqueId, name: 'Foo'),
                typeArguments: [barType]),
          );
          expectSerializationEquality<DeclarationImpl>(
              typeAlias, mode, RemoteInstance.deserialize);
        });

        /// Transitively tests [RecordField]
        test('RecordTypeAnnotation', () {
          var recordType = RecordTypeAnnotationImpl(
            id: RemoteInstance.uniqueId,
            isNullable: true,
            namedFields: [
              RecordFieldDeclarationImpl(
                id: RemoteInstance.uniqueId,
                identifier:
                    IdentifierImpl(id: RemoteInstance.uniqueId, name: r'hello'),
                name: 'hello',
                type: barType,
              ),
            ],
            positionalFields: [
              RecordFieldDeclarationImpl(
                id: RemoteInstance.uniqueId,
                identifier:
                    IdentifierImpl(id: RemoteInstance.uniqueId, name: r'$1'),
                name: null,
                type: fooType,
              ),
            ],
          );
          expectSerializationEquality<TypeAnnotationImpl>(
              recordType, mode, RemoteInstance.deserialize);
        });
      });
    }
  });

  group('Arguments', () {
    test('can create properly typed collections', () {
      withSerializationMode(SerializationMode.jsonClient, () {
        final parsed = Arguments.deserialize(deserializerFactory([
          // positional args
          [
            // int
            ArgumentKind.int.index,
            1,
            // List<int>
            ArgumentKind.list.index,
            [ArgumentKind.int.index],
            [
              ArgumentKind.int.index,
              1,
              ArgumentKind.int.index,
              2,
              ArgumentKind.int.index,
              3,
            ],
            // List<Set<String>>
            ArgumentKind.list.index,
            [ArgumentKind.set.index, ArgumentKind.string.index],
            [
              // Set<String>
              ArgumentKind.set.index,
              [ArgumentKind.string.index],
              [
                ArgumentKind.string.index,
                'hello',
                ArgumentKind.string.index,
                'world',
              ]
            ],
            // Map<int, List<String>>
            ArgumentKind.map.index,
            [
              ArgumentKind.int.index,
              ArgumentKind.nullable.index,
              ArgumentKind.list.index,
              ArgumentKind.string.index
            ],
            [
              // key: int
              ArgumentKind.int.index,
              4,
              // value: List<String>
              ArgumentKind.list.index,
              [ArgumentKind.string.index],
              [
                ArgumentKind.string.index,
                'zip',
              ],
              ArgumentKind.int.index,
              5,
              ArgumentKind.nil.index,
            ]
          ],
          // named args
          [],
        ]));
        expect(parsed.positional.length, 4);
        expect(parsed.positional.first.value, 1);
        expect(parsed.positional[1].value, [1, 2, 3]);
        expect(parsed.positional[1].value, isA<List<int>>());
        expect(parsed.positional[2].value, [
          {'hello', 'world'}
        ]);
        expect(parsed.positional[2].value, isA<List<Set<String>>>());
        expect(
          parsed.positional[3].value,
          {
            4: ['zip'],
            5: null,
          },
        );
        expect(parsed.positional[3].value, isA<Map<int, List<String>?>>());
      });
    });

    group('can be serialized and deserialized', () {
      for (var mode in [
        SerializationMode.byteDataServer,
        SerializationMode.jsonServer
      ]) {
        test('with mode $mode', () {
          final arguments = Arguments([
            MapArgument({
              StringArgument('hello'): ListArgument(
                  [BoolArgument(true), NullArgument()],
                  [ArgumentKind.nullable, ArgumentKind.bool]),
            }, [
              ArgumentKind.string,
              ArgumentKind.list,
              ArgumentKind.nullable,
              ArgumentKind.bool
            ]),
            CodeArgument(ExpressionCode.fromParts([
              '1 + ',
              IdentifierImpl(id: RemoteInstance.uniqueId, name: 'a')
            ])),
            ListArgument([
              TypeAnnotationArgument(Fixtures.myClassType),
              TypeAnnotationArgument(Fixtures.myEnumType),
              TypeAnnotationArgument(NamedTypeAnnotationImpl(
                  id: RemoteInstance.uniqueId,
                  isNullable: false,
                  identifier:
                      IdentifierImpl(id: RemoteInstance.uniqueId, name: 'List'),
                  typeArguments: [Fixtures.stringType])),
            ], [
              ArgumentKind.typeAnnotation
            ])
          ], {
            'a': SetArgument([
              MapArgument({
                IntArgument(1): StringArgument('1'),
              }, [
                ArgumentKind.int,
                ArgumentKind.string
              ])
            ], [
              ArgumentKind.map,
              ArgumentKind.int,
              ArgumentKind.string
            ])
          });
          expectSerializationEquality(arguments, mode, Arguments.deserialize);
        });
      }
    });
  });
}

/// Serializes [serializable] in server mode, then deserializes it in client
/// mode, and checks that all the fields are the same.
void expectSerializationEquality<T extends Serializable>(T serializable,
    SerializationMode serverMode, T deserialize(Deserializer deserializer)) {
  late Object? serialized;
  withSerializationMode(serverMode, () {
    var serializer = serializerFactory();
    serializable.serialize(serializer);
    serialized = serializer.result;
  });
  withSerializationMode(_clientModeForServerMode(serverMode), () {
    var deserializer = deserializerFactory(serialized);
    var deserialized = deserialize(deserializer);

    expect(
        serializable,
        (switch (deserialized) {
          Declaration() => deepEqualsDeclaration(deserialized as Declaration),
          TypeAnnotation() =>
            deepEqualsTypeAnnotation(deserialized as TypeAnnotation),
          Arguments() => deepEqualsArguments(deserialized),
          _ =>
            throw new UnsupportedError('Unsupported object type $deserialized'),
        }));
  });
}

/// Deserializes [serialized] in client mode and sends it back.
Object? roundTrip<Declaration>(Object? serialized) {
  return withSerializationMode(_clientModeForServerMode(serializationMode), () {
    var deserializer = deserializerFactory(serialized);
    var instance = RemoteInstance.deserialize(deserializer);
    var serializer = serializerFactory();
    instance.serialize(serializer);
    return serializer.result;
  });
}

SerializationMode _clientModeForServerMode(SerializationMode serverMode) {
  switch (serverMode) {
    case SerializationMode.byteDataServer:
      return SerializationMode.byteDataClient;
    case SerializationMode.jsonServer:
      return SerializationMode.jsonClient;
    default:
      throw StateError('Expected to be running in a server mode');
  }
}
