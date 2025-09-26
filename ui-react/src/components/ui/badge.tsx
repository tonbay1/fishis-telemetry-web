import * as React from 'react'
import { clsx } from 'clsx'

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'secondary'
}
export const Badge = ({ className, variant = 'default', ...props }: BadgeProps) => (
  <span className={clsx(
    'inline-flex items-center rounded-md px-2.5 py-0.5 text-xs font-semibold transition-colors',
    variant === 'secondary' ? 'bg-secondary text-secondary-foreground' : 'bg-primary text-primary-foreground',
    className
  )} {...props} />
)
export default Badge
