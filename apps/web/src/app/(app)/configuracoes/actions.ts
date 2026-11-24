"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import {
  CAMPO_SESSION_COOKIE,
  campoSessionCookieOptions,
  decodeCampoSession,
  encodeCampoSession,
  toSessionUser,
  type CampoSessionUser,
} from "@/lib/campo-auth";
import {
  changeCampoPassword,
  updateCampoProfile,
} from "@/lib/campo-data";
import { GREET_FULL_NAME_COOKIE } from "@/lib/prefs";

export type SettingsActionState = {
  error?: string;
  ok?: boolean;
  message?: string;
};

async function requireCampoSession(): Promise<
  | { ok: true; session: CampoSessionUser }
  | { ok: false; error: string }
> {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  if (profile.source !== "campo") {
    return {
      ok: false,
      error:
        "Esta conta não está ligada ao cadastro GS Campo. Entre com o login da planilha para alterar perfil e senha.",
    };
  }
  const jar = await cookies();
  const session = decodeCampoSession(jar.get(CAMPO_SESSION_COOKIE)?.value);
  if (!session) return { ok: false, error: "Sessão Campo inválida." };
  return { ok: true, session };
}

export async function saveProfileAction(
  _prev: SettingsActionState,
  formData: FormData,
): Promise<SettingsActionState> {
  const gate = await requireCampoSession();
  if (!gate.ok) return { error: gate.error };

  const name = String(formData.get("name") || "").trim();
  const newLogin = String(formData.get("login") || "").trim().toLowerCase();
  const newEmail = String(formData.get("email") || "").trim().toLowerCase();
  const phone = String(formData.get("phone") || "").trim();
  const password = String(formData.get("password") || "");

  if (!name) return { error: "Informe o nome." };
  if (!newLogin) return { error: "Informe o usuário." };
  if (!newEmail || !newEmail.includes("@")) {
    return { error: "Informe um e-mail válido." };
  }
  if (!password) {
    return { error: "Informe a senha atual para confirmar." };
  }

  const result = await updateCampoProfile({
    email: gate.session.email,
    login: gate.session.login,
    password,
    name,
    newLogin,
    newEmail,
    phone,
  });
  if (!result.ok) return { error: result.error };

  const jar = await cookies();
  jar.set(
    CAMPO_SESSION_COOKIE,
    encodeCampoSession(toSessionUser(result.user)),
    campoSessionCookieOptions,
  );
  revalidatePath("/configuracoes");
  revalidatePath("/");
  return { ok: true, message: "Perfil atualizado na planilha e nesta sessão." };
}

export async function changePasswordAction(
  _prev: SettingsActionState,
  formData: FormData,
): Promise<SettingsActionState> {
  const gate = await requireCampoSession();
  if (!gate.ok) return { error: gate.error };

  const currentPassword = String(formData.get("currentPassword") || "");
  const newPassword = String(formData.get("newPassword") || "");
  const confirmPassword = String(formData.get("confirmPassword") || "");

  if (!currentPassword) return { error: "Informe a senha atual." };
  if (newPassword.length < 4) {
    return { error: "A senha nova precisa ter pelo menos 4 caracteres." };
  }
  if (newPassword !== confirmPassword) {
    return { error: "A confirmação não confere com a senha nova." };
  }

  const result = await changeCampoPassword({
    email: gate.session.email,
    login: gate.session.login,
    currentPassword,
    newPassword,
  });
  if (!result.ok) return { error: result.error };

  revalidatePath("/configuracoes");
  return {
    ok: true,
    message: "Senha atualizada. Use a nova senha no próximo login.",
  };
}

export async function setGreetFullNameAction(value: boolean) {
  const jar = await cookies();
  jar.set(GREET_FULL_NAME_COOKIE, value ? "1" : "0", {
    httpOnly: false,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
  });
  revalidatePath("/");
  revalidatePath("/configuracoes");
  return { ok: true as const };
}
