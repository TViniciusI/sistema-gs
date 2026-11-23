/** Pastas das OS no Drive raiz GS Campo (fallback até o gate listosdrive estar publicado). */
export const CAMPO_DRIVE_ROOT_ID = "1VZHSOnhNrTgccGU-aRrTD4v3hriE2jnC";
export const CAMPO_DRIVE_ROOT_URL =
  "https://drive.google.com/drive/folders/1VZHSOnhNrTgccGU-aRrTD4v3hriE2jnC";

type OsDriveFolders = {
  id: string;
  url: string;
  rdoId?: string;
  rdoUrl?: string;
  certificadosId?: string;
  certificadosUrl?: string;
};

const OS_FOLDERS: Record<string, OsDriveFolders> = {
  "016/26": {
    id: "19DkdgrJ-JJ9R_UdVmOXl-zyFvRYDb4XH",
    url: "https://drive.google.com/drive/folders/19DkdgrJ-JJ9R_UdVmOXl-zyFvRYDb4XH",
    rdoId: "1YMqzZrHPf6TcfgGVZG3GBLKk2a0h-fNG",
    rdoUrl:
      "https://drive.google.com/drive/folders/1YMqzZrHPf6TcfgGVZG3GBLKk2a0h-fNG",
  },
  "017/26": {
    id: "1q_6z9UTxicivGsjFvvlgkjwy4oQG4lCg",
    url: "https://drive.google.com/drive/folders/1q_6z9UTxicivGsjFvvlgkjwy4oQG4lCg",
    rdoId: "1idSOZIUQKhY-KQbmWoOWDfXBXLA3xdsU",
    rdoUrl:
      "https://drive.google.com/drive/folders/1idSOZIUQKhY-KQbmWoOWDfXBXLA3xdsU",
    certificadosId: "1uLPJURkVSENIUEoeZb__UtucsEZ93mWK",
    certificadosUrl:
      "https://drive.google.com/drive/folders/1uLPJURkVSENIUEoeZb__UtucsEZ93mWK",
  },
  "026/26": {
    id: "1cgNZi68XrBHJgFSpdy62Xz5GKPQgdt8m",
    url: "https://drive.google.com/drive/folders/1cgNZi68XrBHJgFSpdy62Xz5GKPQgdt8m",
    rdoId: "1QECosaw4yfYz0CcapPCyzRf8_u8ZV2Cd",
    rdoUrl:
      "https://drive.google.com/drive/folders/1QECosaw4yfYz0CcapPCyzRf8_u8ZV2Cd",
  },
  "043/26": {
    id: "1EYm5HQRnkKpGEu0lmQjUrWVs9rLjxtPu",
    url: "https://drive.google.com/drive/folders/1EYm5HQRnkKpGEu0lmQjUrWVs9rLjxtPu",
    rdoId: "1mN2GPBK0M8w_5vQf47iYySmER1P9lGUV",
    rdoUrl:
      "https://drive.google.com/drive/folders/1mN2GPBK0M8w_5vQf47iYySmER1P9lGUV",
    certificadosId: "1VRlHjjxvpLKcobT65eQK1GOe6Ge4W1zK",
    certificadosUrl:
      "https://drive.google.com/drive/folders/1VRlHjjxvpLKcobT65eQK1GOe6Ge4W1zK",
  },
  "044/26": {
    id: "1ZtLOPAIisy4A9cy7VTM_BKaYjNGbWUlF",
    url: "https://drive.google.com/drive/folders/1ZtLOPAIisy4A9cy7VTM_BKaYjNGbWUlF",
    rdoId: "1JX7-nYCLBmPoUUkcjbhSruTmqG2CRUaH",
    rdoUrl:
      "https://drive.google.com/drive/folders/1JX7-nYCLBmPoUUkcjbhSruTmqG2CRUaH",
    certificadosId: "107inCKLuuT9ABxjelIuZCnY9PAW0XkTU",
    certificadosUrl:
      "https://drive.google.com/drive/folders/107inCKLuuT9ABxjelIuZCnY9PAW0XkTU",
  },
  "045/26": {
    id: "1_neRvx-qD3n6P3UYTA4M-a_RoDj9DjBg",
    url: "https://drive.google.com/drive/folders/1_neRvx-qD3n6P3UYTA4M-a_RoDj9DjBg",
    rdoId: "1psYvOIZX72f1xzUBp8YcPWYJts3eKNPq",
    rdoUrl:
      "https://drive.google.com/drive/folders/1psYvOIZX72f1xzUBp8YcPWYJts3eKNPq",
    certificadosId: "14GOgRwbkaU8O2EgzhZge9NpeTipYyhv5",
    certificadosUrl:
      "https://drive.google.com/drive/folders/14GOgRwbkaU8O2EgzhZge9NpeTipYyhv5",
  },
  "046/26": {
    id: "1ksZCkeuzF9Ai3S-sv_dkBdgH3tt5Bevv",
    url: "https://drive.google.com/drive/folders/1ksZCkeuzF9Ai3S-sv_dkBdgH3tt5Bevv",
    rdoId: "1aYtuW0IAOFSkkZ7lNYO6IZ3hSLZWI71_",
    rdoUrl:
      "https://drive.google.com/drive/folders/1aYtuW0IAOFSkkZ7lNYO6IZ3hSLZWI71_",
  },
  "047/26": {
    id: "1PgiJGHTpe3iJ8KMe_a1DU8mIdA-e6tSe",
    url: "https://drive.google.com/drive/folders/1PgiJGHTpe3iJ8KMe_a1DU8mIdA-e6tSe",
    rdoId: "1nzX4aiCTFczDEltO3-mjiNsjAGKswobv",
    rdoUrl:
      "https://drive.google.com/drive/folders/1nzX4aiCTFczDEltO3-mjiNsjAGKswobv",
    certificadosId: "1jDVq1xe4flmNz2Acy3pU4LSqgDXfNZhr",
    certificadosUrl:
      "https://drive.google.com/drive/folders/1jDVq1xe4flmNz2Acy3pU4LSqgDXfNZhr",
  },
  "048/26": {
    id: "1z2_wvKs1UjydDI-x-16ysqxFxgUs5R_X",
    url: "https://drive.google.com/drive/folders/1z2_wvKs1UjydDI-x-16ysqxFxgUs5R_X",
    rdoId: "1lbI-i6bwTi6eyQVXd4_uvo7vWGOS0HDJ",
    rdoUrl:
      "https://drive.google.com/drive/folders/1lbI-i6bwTi6eyQVXd4_uvo7vWGOS0HDJ",
    certificadosId: "1OF7nfVojsgYy86FB-k6dG6YWDvlGQCNK",
    certificadosUrl:
      "https://drive.google.com/drive/folders/1OF7nfVojsgYy86FB-k6dG6YWDvlGQCNK",
  },
};

export function osFolderKey(osNumber: string) {
  return osNumber.trim().replace(/\//g, "-");
}

export function getKnownOsDriveFolders(osNumber: string): OsDriveFolders | null {
  const direct = OS_FOLDERS[osNumber.trim()];
  if (direct) return direct;
  const key = osFolderKey(osNumber);
  for (const [number, folders] of Object.entries(OS_FOLDERS)) {
    if (osFolderKey(number) === key) return folders;
  }
  return null;
}
