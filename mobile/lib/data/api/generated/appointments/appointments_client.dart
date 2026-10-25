// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/appointment_request.dart';
import '../models/appointment_response.dart';
import '../models/complete_appointment_request.dart';
import '../models/complete_appointment_response.dart';

part 'appointments_client.g.dart';

@RestApi()
abstract class AppointmentsClient {
  factory AppointmentsClient(Dio dio, {String? baseUrl}) = _AppointmentsClient;

  /// Visits, optionally of one pet: planned ones first (soonest first), then past and cancelled (newest first).
  @GET('/api/v1/appointments')
  Future<List<AppointmentResponse>> listAppointments({
    @Query('petId') String? petId,
  });

  /// Add a visit; reminders come a day and two hours before by default.
  @POST('/api/v1/appointments')
  Future<AppointmentResponse> createAppointment({
    @Body() required AppointmentRequest body,
  });

  /// One visit.
  @GET('/api/v1/appointments/{id}')
  Future<AppointmentResponse> getAppointment({
    @Path('id') required String id,
  });

  /// Change a visit, cancel it or plan it again.
  @PUT('/api/v1/appointments/{id}')
  Future<AppointmentResponse> updateAppointment({
    @Path('id') required String id,
    @Body() required AppointmentRequest body,
  });

  /// Delete a visit. Records made from it stay.
  @DELETE('/api/v1/appointments/{id}')
  Future<void> deleteAppointment({
    @Path('id') required String id,
  });

  /// "The visit took place": optionally a care record for each pet and "Done" for their plans.
  @POST('/api/v1/appointments/{id}/complete')
  Future<CompleteAppointmentResponse> completeAppointment({
    @Path('id') required String id,
    @Body() required CompleteAppointmentRequest body,
  });
}
