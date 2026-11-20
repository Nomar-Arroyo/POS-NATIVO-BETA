import { Product, Category } from '../../types';

export const demoCategories: Category[] = [
  { id: 'cat-1', name: 'Bebidas', order: 1 },
  { id: 'cat-2', name: 'Paninis', order: 2 },
  { id: 'cat-3', name: 'Jugos', order: 3 },
  { id: 'cat-4', name: 'Aguas', order: 4 },
  { id: 'cat-5', name: 'Comida', order: 5 },
  { id: 'cat-6', name: 'Desayunos', order: 6 },
  { id: 'cat-7', name: 'Postres', order: 7 },
  { id: 'cat-8', name: 'Extras', order: 8 }
];

export const demoProducts: Product[] = [
  // BEBIDAS - BARRA
  {
    id: 'prod-1',
    name: 'Café Americano',
    description: 'Café negro tradicional',
    category: 'Bebidas',
    price: 2.50,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 100
  },
  {
    id: 'prod-2',
    name: 'Café con Leche',
    description: 'Café con leche vaporizada',
    category: 'Bebidas',
    price: 3.00,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 80
  },
  {
    id: 'prod-3',
    name: 'Capuchino',
    description: 'Café con leche y espuma',
    category: 'Bebidas',
    price: 3.50,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 60
  },
  {
    id: 'prod-4',
    name: 'Té Negro',
    description: 'Té negro tradicional',
    category: 'Bebidas',
    price: 2.00,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 50
  },
  {
    id: 'prod-5',
    name: 'Chocolate Caliente',
    description: 'Chocolate caliente con leche',
    category: 'Bebidas',
    price: 3.20,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 40
  },

  // PANINIS - COCINA
  {
    id: 'prod-6',
    name: 'Panini de Pollo',
    description: 'Panini con pollo y verduras',
    category: 'Paninis',
    price: 5.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 30
  },
  {
    id: 'prod-7',
    name: 'Panini de Jamón y Queso',
    description: 'Panini clásico de jamón y queso',
    category: 'Paninis',
    price: 4.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 35
  },
  {
    id: 'prod-8',
    name: 'Panini de Vegetariano',
    description: 'Panini con verduras y queso',
    category: 'Paninis',
    price: 5.00,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 25
  },

  // JUGOS - BARRA
  {
    id: 'prod-9',
    name: 'Jugo de Naranja',
    description: 'Jugo de naranja natural',
    category: 'Jugos',
    price: 3.00,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 50
  },
  {
    id: 'prod-10',
    name: 'Jugo de Parchita',
    description: 'Jugo de parchita ácido',
    category: 'Jugos',
    price: 3.50,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 45
  },
  {
    id: 'prod-11',
    name: 'Jugo de Mango',
    description: 'Jugo de mango dulce',
    category: 'Jugos',
    price: 3.20,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 40
  },

  // AGUAS - BARRA
  {
    id: 'prod-12',
    name: 'Agua Mineral',
    description: 'Agua mineral sin gas',
    category: 'Aguas',
    price: 1.50,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 100
  },
  {
    id: 'prod-13',
    name: 'Agua con Gas',
    description: 'Agua mineral con gas',
    category: 'Aguas',
    price: 1.80,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 80
  },

  // COMIDA - COCINA
  {
    id: 'prod-14',
    name: 'Desayuno Criollo',
    description: 'Arepa, jamón, queso y huevo',
    category: 'Comida',
    price: 6.00,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 20
  },
  {
    id: 'prod-15',
    name: 'Tostadas',
    description: 'Tostadas con mermelada',
    category: 'Comida',
    price: 3.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 30
  },
  {
    id: 'prod-16',
    name: 'Hamburguesa',
    description: 'Hamburguesa de carne con queso',
    category: 'Comida',
    price: 7.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 25
  },

  // DESAYUNOS - COCINA
  {
    id: 'prod-17',
    name: 'Arepas Rellenas',
    description: 'Arepas con Various rellenos',
    category: 'Desayunos',
    price: 5.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 20
  },
  {
    id: 'prod-18',
    name: 'Crepas',
    description: 'Crepas con azúcar y canela',
    category: 'Desayunos',
    price: 4.00,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 15
  },

  // POSTRES - COCINA
  {
    id: 'prod-19',
    name: 'Tarta de Queso',
    description: 'Postre de tarta de queso',
    category: 'Postres',
    price: 4.00,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 12
  },
  {
    id: 'prod-20',
    name: 'Flan',
    description: 'Flan de caramelo tradicional',
    category: 'Postres',
    price: 3.50,
    station: 'COCINA',
    available: true,
    active: true,
    stock: 15
  },

  // EXTRAS - BARRA
  {
    id: 'prod-21',
    name: 'Extra de Café',
    description: 'Adición de café adicional',
    category: 'Extras',
    price: 1.00,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 200
  },
  {
    id: 'prod-22',
    name: 'Azúcar',
    description: 'Sobre de azúcar',
    category: 'Extras',
    price: 0.25,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 500
  },
  {
    id: 'prod-23',
    name: 'Endulzante',
    description: 'Sobre de endulzante artificial',
    category: 'Extras',
    price: 0.30,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 300
  }
];