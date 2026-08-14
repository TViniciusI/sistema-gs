import type { ReactNode } from "react";

function Svg({ children }: { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="h-[18px] w-[18px] shrink-0"
      aria-hidden
    >
      {children}
    </svg>
  );
}

export const Icons = {
  home: (
    <Svg>
      <path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z" />
    </Svg>
  ),
  clipboard: (
    <Svg>
      <rect x="6" y="4" width="12" height="16" rx="2" />
      <path d="M9 4.5h6v2H9zM8 10h8M8 14h6" />
    </Svg>
  ),
  calendar: (
    <Svg>
      <rect x="4" y="5" width="16" height="15" rx="2" />
      <path d="M8 3v4M16 3v4M4 10h16" />
    </Svg>
  ),
  building: (
    <Svg>
      <path d="M5 21V5a1 1 0 0 1 1-1h8v17M14 9h4a1 1 0 0 1 1 1v11M9 8h2M9 12h2M9 16h2" />
    </Svg>
  ),
  pin: (
    <Svg>
      <path d="M12 21s7-5.4 7-11a7 7 0 1 0-14 0c0 5.6 7 11 7 11z" />
      <circle cx="12" cy="10" r="2.2" />
    </Svg>
  ),
  wrench: (
    <Svg>
      <path d="M14.7 6.3a4.5 4.5 0 0 0-6.2 6.2L4 17l3 3 4.5-4.5a4.5 4.5 0 0 0 6.2-6.2L15 12z" />
    </Svg>
  ),
  users: (
    <Svg>
      <circle cx="9" cy="8" r="3" />
      <path d="M3.5 19a5.5 5.5 0 0 1 11 0" />
      <circle cx="17" cy="9" r="2.4" />
      <path d="M16 19a4.5 4.5 0 0 1 5-4.4" />
    </Svg>
  ),
  shield: (
    <Svg>
      <path d="M12 3 5 6v6c0 4.2 2.8 7.2 7 8.8 4.2-1.6 7-4.6 7-8.8V6z" />
      <path d="m9 12 2 2 4-4" />
    </Svg>
  ),
  clock: (
    <Svg>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 8v4.5l3 1.5" />
    </Svg>
  ),
  phone: (
    <Svg>
      <rect x="8" y="3" width="8" height="18" rx="2" />
      <path d="M11 18h2" />
    </Svg>
  ),
  headset: (
    <Svg>
      <path d="M4 13v-1a8 8 0 0 1 16 0v1" />
      <rect x="3" y="13" width="4" height="6" rx="1" />
      <rect x="17" y="13" width="4" height="6" rx="1" />
      <path d="M21 16h1a2 2 0 0 1 2 2v0a2 2 0 0 1-2 2h-3" />
    </Svg>
  ),
  settings: (
    <Svg>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3v2.2M12 18.8V21M4.9 6.5l1.6 1.6M17.5 17.9l1.6 1.6M3 12h2.2M18.8 12H21M4.9 17.5l1.6-1.6M17.5 6.1l1.6-1.6" />
    </Svg>
  ),
  logout: (
    <Svg>
      <path d="M10 17v2a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M15 12H8M15 12l-3-3M15 12l-3 3" />
    </Svg>
  ),
  chevronRight: (
    <Svg>
      <path d="m9 6 6 6-6 6" />
    </Svg>
  ),
  chevronLeft: (
    <Svg>
      <path d="m15 6-6 6 6 6" />
    </Svg>
  ),
  menu: (
    <Svg>
      <path d="M4 7h16M4 12h16M4 17h16" />
    </Svg>
  ),
  chart: (
    <Svg>
      <path d="M4 19h16M7 16v-5M12 16V8M17 16v-8" />
    </Svg>
  ),
  table: (
    <Svg>
      <rect x="4" y="5" width="16" height="14" rx="1.5" />
      <path d="M4 10h16M4 15h16M10 5v14" />
    </Svg>
  ),
};
