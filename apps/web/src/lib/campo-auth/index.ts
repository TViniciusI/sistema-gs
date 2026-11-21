export { loginWithCampoGate } from "./gate-client";
export { mapCampoRole, toSessionUser, campoRoleLabel } from "./map-role";
export {
  CAMPO_SESSION_COOKIE,
  campoSessionCookieOptions,
  encodeCampoSession,
  decodeCampoSession,
  readCampoSessionFromRequest,
  clearCampoSessionCookie,
} from "./session";
export type { CampoGateUser, CampoSessionUser, CampoLoginResult } from "./types";
