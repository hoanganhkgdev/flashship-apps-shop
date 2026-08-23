import 'package:dio/dio.dart';
import 'package:flashship_shop/core/api/api_client.dart' show apiHasMore;
import 'package:flashship_shop/core/api/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DioException apiError(Object? data, {int statusCode = 422}) => DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: statusCode,
          data: data,
        ),
      );

  test('uses the API message when available', () {
    expect(
      parseApiError(apiError({'message': 'Số điện thoại không hợp lệ'})),
      'Số điện thoại không hợp lệ',
    );
  });

  test('falls back to the first Laravel validation error', () {
    expect(
      parseApiError(apiError({
        'errors': {
          'phone': ['Vui lòng nhập số điện thoại'],
        },
      })),
      'Vui lòng nhập số điện thoại',
    );
  });

  test('uses status code for an unstructured server response', () {
    expect(parseApiError(apiError('bad gateway', statusCode: 502)),
        'Server lỗi 502');
  });

  test('uses the caller fallback for an unrelated exception', () {
    expect(parseApiError(StateError('boom'), fallback: 'Thử lại sau'),
        'Thử lại sau');
  });

  test('reads has_more from both supported pagination contracts', () {
    Response<dynamic> response(Object data) => Response(
          requestOptions: RequestOptions(path: '/test'),
          data: data,
        );

    expect(apiHasMore(response({'has_more': true})), isTrue);
    expect(
      apiHasMore(response({
        'meta': {'has_more': true},
      })),
      isTrue,
    );
    expect(apiHasMore(response({'data': []})), isFalse);
  });
}
