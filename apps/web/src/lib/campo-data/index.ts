export { listCampoClients, getCampoClient, deleteCampoClientSystem } from "./clients";
export { listCampoOrders, getCampoOrder, saveCampoOrder } from "./orders";
export {
  isExcludedFromTechLoad,
  isFieldTechnicianUser,
  isOfficeHiddenOrder,
} from "./office-filters";
export {
  calibrationsForOs,
  campoAppUrl,
  certificatesForOs,
  DEFAULT_TECHNICIAN_CARGO,
  formatRdoDate,
  formatRdoSignedAt,
  getCampoPublicCertificate,
  groupCertificatesByKind,
  groupSlotsByKind,
  GS_COMPANY_CNPJ,
  GS_COMPANY_NAME,
  jobForSlot,
  kindLabel,
  parseOsCalibrationSlots,
  parseOsRdoMeta,
  parseOsRdos,
  personFirstKey,
  publicCertUrl,
  splitTeamNames,
  teamWithLead,
} from "./os-docs";
export type {
  CampoPublicCertificate,
  OsCalibrationSlotLite,
  OsCertificateRow,
  OsRdoLite,
  OsRdoMeta,
} from "./os-docs";
export { listCampoUsers } from "./users";
export { getCampoDriveStatus } from "./drive";
export {
  getCampoCalibration,
  listCampoCalibrations,
  listCampoStandards,
  listCampoFluids,
  listCampoStaffDocs,
} from "./catalog";
export type {
  CampoClient,
  CampoClientSystem,
  CampoOrder,
  CampoUser,
  CampoDriveStatus,
} from "./types";
export type {
  CampoCalibration,
  CampoStandard,
  CampoFluid,
  CampoStaffDoc,
} from "./catalog";
