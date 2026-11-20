import React from 'react'

const iconNames = [
  'alert',
  'audit',
  'backup',
  'bar',
  'beans',
  'bell',
  'calculator',
  'calendar',
  'card',
  'cart',
  'cash',
  'categories',
  'chart',
  'check',
  'chef-hat',
  'chevron-right',
  'clock',
  'close',
  'coffee',
  'cup',
  'currency',
  'dashboard',
  'delivery',
  'edit',
  'help',
  'history',
  'info',
  'inventory',
  'invoice',
  'kitchen',
  'leaf',
  'lock',
  'logout',
  'menu',
  'minus',
  'mobile-payment',
  'orders',
  'package',
  'payment',
  'plus',
  'pos',
  'printer',
  'products',
  'receipt',
  'refresh',
  'reports',
  'restore',
  'search',
  'settings',
  'split-bill',
  'star',
  'stock',
  'table',
  'tables',
  'takeout',
  'ticket',
  'transfer',
  'trash',
  'unlock',
  'user',
  'users',
  'wifi-off'
] as const

export type IconName = typeof iconNames[number]

export interface IconProps extends Omit<React.SVGProps<SVGSVGElement>, 'color'> {
  name: IconName
  size?: number | string
  color?: string
}

const iconSources = import.meta.glob<string>('../../assets/icons/*.svg', {
  eager: true,
  query: '?raw',
  import: 'default'
})

const iconMarkup = iconNames.reduce((markup, name) => {
  const source = iconSources[`../../assets/icons/${name}.svg`]
  const match = source?.match(/<svg\b[^>]*>([\s\S]*?)<\/svg>/i)

  if (!match) {
    throw new Error(`No se pudo cargar el icono SVG "${name}"`)
  }

  markup[name] = match[1]
  return markup
}, {} as Record<IconName, string>)

const Icon: React.FC<IconProps> = ({
  name,
  size = 24,
  color = 'currentColor',
  className,
  style,
  'aria-label': ariaLabel,
  ...svgProps
}) => (
  <svg
    {...svgProps}
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    width={size}
    height={size}
    fill="none"
    stroke="currentColor"
    strokeWidth={1.7}
    strokeLinecap="round"
    strokeLinejoin="round"
    className={className}
    style={{ color, ...style }}
    role={ariaLabel ? 'img' : undefined}
    aria-label={ariaLabel}
    aria-hidden={ariaLabel ? undefined : true}
    // The markup comes only from the checked-in, local icon package.
    dangerouslySetInnerHTML={{ __html: iconMarkup[name] }}
  />
)

Icon.displayName = 'Icon'

type IconAliasProps = Omit<IconProps, 'name'>

const createIconAlias = (
  name: IconName,
  extraClassName = ''
): React.FC<IconAliasProps> => {
  const IconAlias: React.FC<IconAliasProps> = ({ className, ...props }) => (
    <Icon
      {...props}
      name={name}
      className={[extraClassName, className].filter(Boolean).join(' ') || undefined}
    />
  )

  IconAlias.displayName = `Amalfi${name.replace(/(^|-)(\w)/g, (_, _separator, letter: string) => letter.toUpperCase())}Icon`
  return IconAlias
}

export const HomeIcon = createIconAlias('dashboard')
export const TableCellsIcon = createIconAlias('tables')
export const ShoppingBagIcon = createIconAlias('cart')
export const DocumentTextIcon = createIconAlias('invoice')
export const ArchiveBoxIcon = createIconAlias('package')
export const CurrencyDollarIcon = createIconAlias('currency')
export const ChartBarIcon = createIconAlias('chart')
export const CogIcon = createIconAlias('settings')
export const FireIcon = createIconAlias('chef-hat')
export const CalendarClockIcon = createIconAlias('calendar')
export const UserIcon = createIconAlias('user')
export const BuildingOfficeIcon = createIconAlias('coffee')
export const XMarkIcon = createIconAlias('close')
export const CheckCircleIcon = createIconAlias('check')
export const ExclamationTriangleIcon = createIconAlias('alert')
export const XCircleIcon = createIconAlias('close')
export const InformationCircleIcon = createIconAlias('info')
export const BellIcon = createIconAlias('bell')
export const BanknotesIcon = createIconAlias('cash')
export const CalendarIcon = createIconAlias('calendar')
export const ArrowDownTrayIcon = createIconAlias('backup')
export const PrinterIcon = createIconAlias('printer')
export const CalculatorIcon = createIconAlias('calculator')
export const CreditCardIcon = createIconAlias('card')
export const ReceiptRefundIcon = createIconAlias('receipt')
export const ClockIcon = createIconAlias('clock')
export const PlusIcon = createIconAlias('plus')
export const MinusIcon = createIconAlias('minus')
export const ArrowLeftIcon = createIconAlias('chevron-right', 'rotate-180')
export const PaperAirplaneIcon = createIconAlias('orders')
export const UsersIcon = createIconAlias('users')
export const TrashIcon = createIconAlias('trash')
export const MagnifyingGlassIcon = createIconAlias('search')
export const Squares2X2Icon = createIconAlias('categories')
export const ListBulletIcon = createIconAlias('orders')
export const AdjustmentsHorizontalIcon = createIconAlias('settings')
export const EyeIcon = createIconAlias('info')

export default Icon
