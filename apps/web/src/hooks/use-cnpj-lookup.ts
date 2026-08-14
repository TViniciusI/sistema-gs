"use client";

import { useCallback, useRef, useState } from "react";
import { digitsOnly } from "@gs/shared";
import {
  lookupCnpj,
  type CnpjLookupResult,
  type LocalCnpjRecord,
} from "@/lib/cnpj";

export function useCnpjLookup(localRecords: LocalCnpjRecord[] = []) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastResult, setLastResult] = useState<CnpjLookupResult | null>(null);
  const lastFetched = useRef("");
  const recordsRef = useRef(localRecords);
  recordsRef.current = localRecords;

  const fetchCnpj = useCallback(async (cnpj: string, force = false) => {
    const digits = digitsOnly(cnpj);
    if (digits.length !== 14) {
      setError(null);
      return null;
    }

    if (!force && lastFetched.current === digits) {
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const result = await lookupCnpj(digits, recordsRef.current);
      lastFetched.current = digits;
      setLastResult(result);
      return result;
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Erro ao consultar CNPJ.";
      setError(message);
      setLastResult(null);
      lastFetched.current = "";
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  return { fetchCnpj, loading, error, lastResult };
}
