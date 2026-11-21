"use client";

import { useActionState } from "react";
import { login, type LoginState } from "./actions";

const initial: LoginState = {};

export function LoginForm() {
  const [state, action, pending] = useActionState(login, initial);

  return (
    <form action={action} className="mt-8 space-y-4">
      <label className="block text-left">
        <span className="mb-1.5 block text-[11px] font-semibold uppercase tracking-[0.16em] text-muted">
          Usuário ou e-mail
        </span>
        <input
          name="login"
          type="text"
          autoComplete="username"
          required
          placeholder="cleber"
          className="w-full rounded-xl border border-navy/15 bg-paper/50 px-3.5 py-3 text-sm text-ink outline-none focus:border-brass"
        />
      </label>
      <label className="block text-left">
        <span className="mb-1.5 block text-[11px] font-semibold uppercase tracking-[0.16em] text-muted">
          Senha
        </span>
        <input
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="w-full rounded-xl border border-navy/15 bg-paper/50 px-3.5 py-3 text-sm text-ink outline-none focus:border-brass"
        />
      </label>

      {state.error ? (
        <p
          role="alert"
          className="rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-800"
        >
          {state.error}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={pending}
        className="mt-2 w-full rounded-xl bg-navy px-6 py-3.5 text-sm font-semibold tracking-[0.06em] text-paper hover:bg-navy-2 disabled:opacity-60"
      >
        {pending ? "Entrando…" : "Entrar no escritório"}
      </button>
    </form>
  );
}
