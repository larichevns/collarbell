// The app's addresses, under /app/ (the router's basename):
//   /                                  Home, where the app opens: a greeting, the pets, what is important right now,
//                                      quick actions
//   /today                             Today: feedings, visits, what to buy, care that is due
//   /welcome?page=&step=               getting to know the app: three pages, then the first steps (a pet, its feeding,
//                                      the family); Home opens it by itself once for a new account
//   /pets                              the household's pets
//   /pets/new                          a new pet (not for helpers)
//   /pets/:id                          a pet: Overview (photo, details, microchips)
//   /pets/:id/health                   its care plan and history; …/passport, …/documents, …/feeding, …/weight
//   /pets/:id/edit                     the pet's details
//   /pets/:id/plans/new                a new plan: the ready-made ones to choose from
//   /pets/:id/plans/new/:preset        the plan form, from a ready-made plan or ("own") by hand
//   /pets/:id/plans/:planId            a plan's form: change, pause, delete
//   /pets/:id/records/new?kind=&target=  a record of the past, by hand
//   /pets/:id/records/import           history from the paper passport, many records at once
//   /pets/:id/records/:recordId        a record: details, photos and files (…/edit: its form)
//   /pets/:id/passport/edit            the passport's details
//   /pets/:id/documents/:documentId    a document: its pages large, details
//   /pets/:id/feeding/new              a new feeding schedule (…/feeding/:routineId: a schedule's form)
//   /pets/:id/scan?source=&again=      a new scan of passport pages or a vet document (?again=: a failed one read again)
//   /pets/:id/note?again=              a note written in words for AI to read (?again=: a failed one read again)
//   /pets/:id/scans/:scanId            a scan or note: being read, then the draft to check; failed, saved, discarded
//   /visits                            visits: planned, then past and cancelled
//   /visits/new?pet=…                  a new visit (for that pet)
//   /visits/:id                        a visit: "The visit took place", cancel, delete
//   /visits/:id/edit                   the visit's details
//   /supplies                          supplies: to buy, running out soon, in stock, no longer bought
//   /supplies/new                      a new item (not for helpers)
//   /supplies/:id                      an item: its forecast, "Bought", "Correct the stock", its history
//   /supplies/:id/edit                 the item's details
//   /settings                          the profile, the theme, the group, its plan, AI, notifications, your data
//   /settings/delete-account           deleting the account: what happens to each group, the password again
//   /join#ABCD-2345                    joining a group with a code (the code after #, from an invite's link)
import type { ComponentType } from 'react';
import { useParams, type RouteObject } from 'react-router';
import { Layout } from './components/Layout';
import { ForEditors } from './components/ForEditors';
import { DocumentPage } from './pages/documents/DocumentPage';
import { HomePage } from './pages/home/HomePage';
import { EditFeedingPage, NewFeedingPage } from './pages/feeding/FeedingFormPage';
import { BulkEntryPage } from './pages/health/BulkEntryPage';
import { EditPlanPage, NewPlanPage } from './pages/health/PlanFormPage';
import { PresetPickerPage } from './pages/health/PresetPickerPage';
import { EditRecordPage, NewRecordPage } from './pages/health/RecordFormPage';
import { RecordPage } from './pages/health/RecordPage';
import { ScanPage } from './pages/scans/ScanPage';
import { NewNotePage, NewScanPage } from './pages/scans/StartPages';
import { DeleteAccountPage } from './pages/settings/DeleteAccountPage';
import { PassportFormPage } from './pages/passport/PassportFormPage';
import { EditPetPage, NewPetPage } from './pages/pets/PetFormPage';
import { PET_TABS, PetPage, type PetTab } from './pages/pets/PetPage';
import { PetsPage } from './pages/pets/PetsPage';
import { NotFoundPage, RouteError } from './pages/RouteError';
import { JoinPage } from './pages/settings/JoinPage';
import { SettingsPage } from './pages/settings/SettingsPage';
import { SuppliesPage } from './pages/supplies/SuppliesPage';
import { EditSupplyPage, NewSupplyPage } from './pages/supplies/SupplyFormPage';
import { SupplyPage } from './pages/supplies/SupplyPage';
import { TodayPage } from './pages/today/TodayPage';
import { EditVisitPage, NewVisitPage } from './pages/visits/VisitFormPage';
import { VisitPage } from './pages/visits/VisitPage';
import { VisitsPage } from './pages/visits/VisitsPage';
import { WelcomePage } from './pages/welcome/WelcomePage';

export const BASENAME = '/app';

/** Another pet, record or visit: a fresh page, nothing carried over from the one before (its dialogs, typed input). */
function Fresh({ page: Page }: { page: ComponentType }) {
  const params = useParams();
  return <Page key={Object.values(params).join('/')} />;
}

/** A form: those who only mark (helpers) get a word instead. */
function Editor({ page }: { page: ComponentType }) {
  return (
    <ForEditors>
      <Fresh page={page} />
    </ForEditors>
  );
}

/** A pet's tab. The same page for every tab of one pet: switching tabs keeps the page and changes the panel. */
function PetRoute({ tab }: { tab: PetTab }) {
  const { id = '' } = useParams();
  return <PetPage key={id} tab={tab} />;
}

export const routes: RouteObject[] = [
  {
    element: <Layout />,
    errorElement: <RouteError />,
    children: [
      {
        // A page that breaks shows the error next to the sidebar.
        errorElement: <RouteError />,
        children: [
          { index: true, element: <HomePage /> },
          { path: 'today', element: <TodayPage /> },
          { path: 'welcome', element: <WelcomePage /> },
          { path: 'pets', element: <PetsPage /> },
          { path: 'pets/new', element: <Editor page={NewPetPage} /> },
          ...PET_TABS.map((tab) => ({
            path: tab === 'overview' ? 'pets/:id' : `pets/:id/${tab}`,
            element: <PetRoute tab={tab} />,
          })),
          { path: 'pets/:id/edit', element: <Editor page={EditPetPage} /> },
          { path: 'pets/:id/plans/new', element: <Editor page={PresetPickerPage} /> },
          { path: 'pets/:id/plans/new/:preset', element: <Editor page={NewPlanPage} /> },
          { path: 'pets/:id/plans/:planId', element: <Editor page={EditPlanPage} /> },
          { path: 'pets/:id/records/new', element: <Editor page={NewRecordPage} /> },
          { path: 'pets/:id/records/import', element: <Editor page={BulkEntryPage} /> },
          { path: 'pets/:id/records/:recordId', element: <Fresh page={RecordPage} /> },
          { path: 'pets/:id/records/:recordId/edit', element: <Editor page={EditRecordPage} /> },
          { path: 'pets/:id/passport/edit', element: <Editor page={PassportFormPage} /> },
          { path: 'pets/:id/documents/:documentId', element: <Fresh page={DocumentPage} /> },
          { path: 'pets/:id/feeding/new', element: <Editor page={NewFeedingPage} /> },
          { path: 'pets/:id/feeding/:routineId', element: <Editor page={EditFeedingPage} /> },
          { path: 'pets/:id/scan', element: <Editor page={NewScanPage} /> },
          { path: 'pets/:id/note', element: <Editor page={NewNotePage} /> },
          { path: 'pets/:id/scans/:scanId', element: <Editor page={ScanPage} /> },
          { path: 'visits', element: <VisitsPage /> },
          { path: 'visits/new', element: <Editor page={NewVisitPage} /> },
          { path: 'visits/:id', element: <Fresh page={VisitPage} /> },
          { path: 'visits/:id/edit', element: <Editor page={EditVisitPage} /> },
          { path: 'supplies', element: <SuppliesPage /> },
          { path: 'supplies/new', element: <Editor page={NewSupplyPage} /> },
          { path: 'supplies/:id', element: <Fresh page={SupplyPage} /> },
          { path: 'supplies/:id/edit', element: <Editor page={EditSupplyPage} /> },
          { path: 'settings', element: <SettingsPage /> },
          { path: 'settings/delete-account', element: <DeleteAccountPage /> },
          { path: 'join', element: <JoinPage /> },
          { path: '*', element: <NotFoundPage /> },
        ],
      },
    ],
  },
];
