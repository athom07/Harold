import React from 'react';

interface HaroldOpticalMarkProps {
  size?: number;
  active?: boolean;
  listening?: boolean;
}

/**
 * Harold's optical emblem: combines the precision teal architectural tile from Harold.svg
 * with a subtle HAL 9000-inspired optical aperture ring that responds calmly to voice & synthesis.
 */
export const HaroldOpticalMark: React.FC<HaroldOpticalMarkProps> = ({
  size = 44,
  active = false,
  listening = false,
}) => {
  const radius = Math.round(size * 0.24);
  return (
    <div
      className="relative inline-flex items-center justify-center shrink-0 select-none"
      style={{ width: size, height: size }}
      aria-hidden="true"
    >
      <svg
        width={size}
        height={size}
        viewBox="0 0 1024 1024"
        style={{ borderRadius: radius }}
        className="shadow-sm"
      >
        <defs>
          <linearGradient id="haroldTile" x1="0" y1="0" x2="0.86" y2="1">
            <stop offset="0%" stopColor="#1E787D" />
            <stop offset="52%" stopColor="#0D525C" />
            <stop offset="100%" stopColor="#052E34" />
          </linearGradient>
          <linearGradient id="haroldFold" x1="0" y1="0" x2="1" y2="0.8">
            <stop offset="0%" stopColor="#04292F" />
            <stop offset="100%" stopColor="#094248" />
          </linearGradient>
          <linearGradient id="haroldSpark" x1="0.5" y1="0" x2="0.5" y2="1">
            <stop offset="0%" stopColor="#FFFFFF" />
            <stop offset="100%" stopColor="#C5DFDB" />
          </linearGradient>
          <radialGradient id="halAperture" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor={listening ? '#FF6B4A' : '#38BDF8'} stopOpacity="0.45" />
            <stop offset="70%" stopColor="#08756E" stopOpacity="0.15" />
            <stop offset="100%" stopColor="#052E34" stopOpacity="0" />
          </radialGradient>
        </defs>
        <rect x="0" y="0" width="1024" height="1024" rx="230" fill="url(#haroldTile)" />
        <path d="M0 0L1024 1024H0Z" fill="url(#haroldFold)" opacity="0.82" />
        <path
          d="M0 0L1024 1024"
          stroke="#81BCC0"
          strokeOpacity="0.28"
          strokeWidth="12"
        />
        {/* HAL 9000-inspired concentric optical calibration rings */}
        <circle
          cx="512"
          cy="512"
          r="350"
          fill="url(#halAperture)"
          stroke={listening ? '#FCA5A5' : '#99F6E4'}
          strokeOpacity={active || listening ? '0.55' : '0.22'}
          strokeWidth="14"
        />
        <circle
          cx="512"
          cy="512"
          r="250"
          fill="none"
          stroke="#E2EBEB"
          strokeOpacity="0.2"
          strokeWidth="8"
          strokeDasharray="28 18"
        />
        {/* Center Harold Spark */}
        <path
          d="M512 252Q556 458 722 512Q556 566 512 772Q468 566 302 512Q468 458 512 252Z"
          fill="url(#haroldSpark)"
        />
        {listening && (
          <circle cx="512" cy="512" r="46" fill="#EF4444" />
        )}
      </svg>
    </div>
  );
};
