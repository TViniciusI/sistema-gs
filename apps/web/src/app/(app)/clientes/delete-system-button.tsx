"use client";

import { useActionState } from "react";
import {
  deleteClientSystemAction,
  type DeleteSystemState,
} from "./actions";

const initial: DeleteSystemState = {};

export function DeleteSystemButton({
  clientId,
  systemId,
  label,
}: {
  clientId: string;
  systemId: string;
  label: string;
}) {
  const [state, action, pending] = useActionState(
    deleteClientSystemAction,
    initial,
  );

  return (
    <form action={action} className="inline">
      <input type="hidden" name="clientId" value={clientId} />
      <input type="hidden" name="systemId" value={systemId} />
      <button
        type="submit"
        disabled={pending}
        title={`Apagar ${label}`}
        aria-label={`Apagar ${label}`}
        onClick={(event) => {
          if (
            !confirm(
              `Apagar “${label}” do cadastro? A alteração vai para a planilha e o GS Campo (após sync).`,
            )
          ) {
            event.preventDefault();
          }
        }}
        className="rounded-md p-2 text-navy/40 hover:bg-red-50 hover:text-red-700 disabled:opacity-50"
      >
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          aria-hidden
        >
          <path d="M4 7h16" />
          <path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
          <path d="M10 11v6M14 11v6" />
          <path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12" />
        </svg>
      </button>
      {state.error ? (
        <span className="ml-2 text-xs text-red-700">{state.error}</span>
      ) : null}
    </form>
  );
}
