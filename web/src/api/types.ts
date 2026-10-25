// Short names for the API's types. All of them come from src/api/schema.d.ts, which npm run generate-api writes from
// contracts/openapi.json: a change of the contract shows up here as a type error, not as a surprise at runtime.
import type { components } from './schema';

type Schemas = components['schemas'];

export type Me = Schemas['MeResponse'];
export type UpdateMeRequest = Schemas['UpdateMeRequest'];
export type HouseholdSummary = Schemas['HouseholdSummary'];
export type HouseholdRole = Schemas['HouseholdRole'];
export type HouseholdDetails = Schemas['HouseholdDetails'];
export type HouseholdMember = Schemas['HouseholdMemberResponse'];
export type HouseholdInvite = Schemas['HouseholdInviteResponse'];
export type InvitePreview = Schemas['InvitePreview'];

export type Plan = Schemas['PlanResponse'];
export type PlanKind = Schemas['PlanKind'];
export type AiStatus = Schemas['AiStatusResponse'];

export type FileLink = Schemas['FileLink'];

export type Today = Schemas['TodayResponse'];
export type TodayFeeding = Schemas['TodayFeedingItem'];
export type TodayCare = Schemas['TodayCareItem'];
export type TodayVisit = Schemas['TodayAppointmentItem'];
export type TodaySupply = Schemas['TodaySupplyItem'];
export type FeedingMark = Schemas['RoutineCompletionResponse'];
export type PortionUnit = NonNullable<Schemas['PortionUnit']>;

export type CarePlan = Schemas['CarePlanResponse'];
export type CarePlanRequest = Schemas['CarePlanRequest'];
export type CarePreset = Schemas['CarePresetResponse'];
export type CareKind = Schemas['CareKind'];
export type CareStatus = Schemas['CareStatus'];
export type IntervalUnit = NonNullable<Schemas['IntervalUnit']>;
export type VaccineTarget = Schemas['VaccineTarget'];
export type CompleteCarePlanRequest = Schemas['CompleteCarePlanRequest'];
export type CareRecord = Schemas['CareRecordResponse'];
export type CareRecordRequest = Schemas['CareRecordRequest'];
export type CareRecordDetails = Schemas['CareRecordDetailsDto'];
export type RecordSource = Schemas['RecordSource'];
export type PassportRecords = Schemas['PassportRecordsResponse'];

export type Passport = Schemas['PassportResponse'];
export type PassportRequest = Schemas['PassportRequest'];
export type PassportModel = NonNullable<Schemas['PassportModel']>;
export type PassportContact = Schemas['PassportContactDto'];

export type PetDocument = Schemas['DocumentResponse'];
export type DocumentRequest = Schemas['DocumentRequest'];
export type DocumentDetailsRequest = Schemas['DocumentDetailsRequest'];
export type DocumentType = Schemas['DocumentType'];

export type Routine = Schemas['RoutineResponse'];
export type RoutineRequest = Schemas['RoutineRequest'];
export type DayOfWeek = Schemas['DayOfWeek'];

export type Weight = Schemas['WeightResponse'];
export type WeightRequest = Schemas['WeightRequest'];
export type WeightSource = Schemas['WeightSource'];

export type Pet = Schemas['PetResponse'];
export type PetRequest = Schemas['PetRequest'];
export type IdentifierType = Schemas['IdentifierType'];
export type Species = Schemas['Species'];
export type Sex = Schemas['Sex'];
export type Coat = Schemas['Coat'];
export type PetStatus = Schemas['PetStatus'];

export type Visit = Schemas['AppointmentResponse'];
export type VisitRequest = Schemas['AppointmentRequest'];
export type VisitType = Schemas['AppointmentType'];
export type VisitStatus = Schemas['AppointmentStatus'];

export type Supply = Schemas['SupplyResponse'];
export type SupplyRequest = Schemas['SupplyRequest'];
export type SupplyCategory = Schemas['SupplyCategory'];
export type SupplyUnit = Schemas['SupplyUnit'];
export type SupplyStatus = Schemas['SupplyStatus'];
export type SupplyUsageMode = Schemas['SupplyUsageMode'];
export type SupplyForecast = Schemas['SupplyForecast'];
export type SupplyFeeding = Schemas['SupplyFeedingResponse'];
export type SupplyDataSource = NonNullable<Schemas['SupplyDataSource']>;
export type StockEvent = Schemas['StockEventResponse'];
export type StockEventKind = Schemas['StockEventKind'];
export type StockEventRequest = Schemas['StockEventRequest'];
export type StockChange = Schemas['StockChangeResponse'];
export type ProductLookup = Schemas['ProductLookupResponse'];
export type ProductDetails = Schemas['ProductDetails'];
export type ProductSource = NonNullable<Schemas['ProductLookupSource']>;
export type ProductDraft = Schemas['ProductDraft'];

export type AiImport = Schemas['AiImportResponse'];
export type AiImportSource = Schemas['AiImportSource'];
export type AiImportStatus = Schemas['AiImportStatus'];
export type AiImportError = NonNullable<Schemas['AiImportError']>;
export type ImportDraft = Schemas['ImportDraft'];
export type DraftRecord = Schemas['DraftRecord'];
export type DraftIdentifier = Schemas['DraftIdentifier'];
export type DraftPassport = Schemas['DraftPassport'];
export type DraftWeight = Schemas['DraftWeight'];
export type DraftWarning = Schemas['DraftWarning'];
export type DraftIssue = Schemas['DraftIssue'];
export type CreateAiImportRequest = Schemas['CreateAiImportRequest'];
export type ApplyImportRequest = Schemas['ApplyImportRequest'];
export type ApplyImportResponse = Schemas['ApplyImportResponse'];
export type PetIdentifierRequest = Schemas['PetIdentifierRequest'];
export type IdentifierReading = Schemas['IdentifierReading'];

export type DeletionPreview = Schemas['AccountDeletionPreview'];
export type HouseholdOutcome = Schemas['HouseholdDeletionOutcome'];
export type HouseholdFate = Schemas['HouseholdFate'];

export type LiveTicket = Schemas['LiveTicketResponse'];
