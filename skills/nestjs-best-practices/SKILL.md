---
name: nestjs-best-practices
description: Guides developers to follow the exact NestJS conventions used in this booking-management-backend project. Use this skill whenever the user asks to create a new module, feature, endpoint, DTO, service, controller, guard, or any NestJS code. Also trigger for questions about project structure, CRUD operations, authentication/authorization, Prisma queries, soft deletes, or how to follow project patterns. If someone says "add a module", "create an endpoint", "new feature", "new entity", "add CRUD" — always use this skill immediately. Don't wait for them to mention "best practices" explicitly.
---

# NestJS Project Conventions — Booking Management Backend

This project is a **NestJS 9+ booking management system** using:
- **Prisma** (PostgreSQL) — the actual ORM, not TypeORM
- **JWT + Passport** for authentication
- **CASL** for role-based authorization (admin/system modules only)
- **Swagger + Scalar** for API docs
- **class-validator / class-transformer** for DTO validation

**Before writing code for any new feature, read at least one similar existing module** to confirm current patterns. Examples: `src/bookings/`, `src/expenses/`, `src/customers/`, `src/users/`.

---

## Project Has Two Module Patterns

Reading the actual codebase reveals two distinct patterns. Choose based on what you're building:

### Pattern A — Business Modules (bookings, expenses, customers, suppliers…)
- `JwtAuthGuard` only
- User passed as `@User() user: UserDto` from controller into service method
- Method names: `findAll` / `findOne`

### Pattern B — Admin/System Modules (users, permissions, uploads, tenant-categories…)
- `JwtAuthGuard` + `PermissionGuard` + `@CheckPermissionsFor`
- `UserProvider.getUser()` called inside service
- Method names: `findMany` / `findUnique`
- `isDeleted: false` filter in queries

When in doubt, match the nearest existing module to what you're building.

---

## 1. Module Folder Structure

```
src/module-name/
├── module-name.module.ts
├── module-name.controller.ts
├── module-name.service.ts
├── dto/
│   ├── create-module-name.dto.ts
│   ├── update-module-name.dto.ts
│   └── module-name-response.dto.ts
└── module-name.spec.ts
```

Add the new module to `src/app.module.ts` imports.

---

## 2. Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | kebab-case | `create-booking.dto.ts` |
| Classes | PascalCase + suffix | `BookingsController`, `BookingsService` |
| Business module methods | `findAll`, `findOne`, `create`, `update`, `remove` | — |
| Admin module methods | `findMany`, `findUnique`, `create`, `update`, `remove` | — |
| DTOs | `Create<X>Dto`, `Update<X>Dto`, `<X>ResponseDto` | `CreateBookingDto` |
| Update DTO | Always `PartialType(CreateDto)` | — |

---

## 3. Controller — Pattern A (Business Module)

```typescript
import { Controller, Get, Post, Body, Patch, Param, Delete, Query, UseGuards, HttpStatus, ValidationPipe } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiResponse, ApiParam } from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { User } from 'src/common/decorators/user.decorator';
import { UserDto } from 'src/users/entities/user.entity';

@ApiTags('products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('products')
export class ProductsController {
  constructor(private readonly service: ProductsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new product' })
  @ApiResponse({ status: HttpStatus.CREATED, type: ProductResponseDto })
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Invalid data' })
  async create(@Body(ValidationPipe) dto: CreateProductDto, @User() user: UserDto) {
    return this.service.create(dto, user);
  }

  @Get()
  @ApiOperation({ summary: 'Get all products with pagination' })
  @ApiResponse({ status: HttpStatus.OK, description: 'List of products' })
  async findAll(@Query() query: any) {
    return this.service.findAll({
      skip: query.skip ? parseInt(query.skip, 10) : 0,
      take: query.take ? parseInt(query.take, 10) : 10,
      query: query.query,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get product by ID' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: HttpStatus.OK, type: ProductResponseDto })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Product not found' })
  async findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update product by ID' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: HttpStatus.OK, type: ProductResponseDto })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Product not found' })
  async update(@Param('id') id: string, @Body(ValidationPipe) dto: UpdateProductDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete product by ID' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Product deleted' })
  async remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
```

---

## 4. Controller — Pattern B (Admin/System Module)

```typescript
import { ParseUUIDPipe } from '@nestjs/common';
import { ApiPaginatedResponse } from 'src/common/decorators/api-paginated-response';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { PermissionGuard } from 'src/auth/guards/permission.guard';
import { CheckPermissionsFor } from 'src/auth/guards/permissions.decorator';

@ApiTags('Products')
@Controller('products')
export class ProductsController {
  constructor(private usersService: ProductsService) {}

  @Get()
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, PermissionGuard)
  @CheckPermissionsFor('Product')   // exact Prisma model name, PascalCase singular
  @ApiOperation({ summary: 'Get all products' })
  @ApiPaginatedResponse(ProductResponseDto)
  findMany(@Query() query: QueryProductDto) {
    return this.service.findMany(query);
  }

  @Get(':id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, PermissionGuard)
  @CheckPermissionsFor('Product')
  @ApiOperation({ summary: 'Get product by ID' })
  @ApiOkResponse({ type: ProductResponseDto })
  findUnique(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.findUnique(id);
  }
}
```

---

## 5. Service — Pattern A (Business Module)

```typescript
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UserDto } from 'src/users/entities/user.entity';
import { Prisma } from '@prisma/client';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateProductDto, user: UserDto) {
    try {
      return await this.prisma.product.create({
        data: { ...dto },
      });
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('Failed to create product');
    }
  }

  async findAll(params?: { skip?: number; take?: number; query?: string }) {
    const { skip = 0, take = 10, query } = params || {};

    const where: Prisma.ProductWhereInput = {
      ...(query && {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
        ],
      }),
    };

    const [data, count] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.product.count({ where }),
    ]);

    return { count, data };
  }

  async findOne(id: string) {
    const record = await this.prisma.product.findUnique({ where: { id } });
    if (!record) throw new NotFoundException(`Product with ID ${id} not found`);
    return record;
  }

  async update(id: string, dto: UpdateProductDto) {
    await this.findOne(id);
    try {
      return await this.prisma.product.update({ where: { id }, data: dto });
    } catch (error) {
      throw new BadRequestException('Failed to update product');
    }
  }

  async remove(id: string): Promise<{ message: string }> {
    await this.findOne(id);
    await this.prisma.product.delete({ where: { id } });
    return { message: `Product with ID ${id} has been deleted` };
  }
}
```

---

## 6. Service — Pattern B (Admin Module with `isDeleted`)

When the Prisma model has an `isDeleted` field (like `User`), use soft deletes:

```typescript
// findMany with isDeleted filter
async findMany(args?: Prisma.ProductFindManyArgs) {
  const where: Prisma.ProductWhereInput = {
    ...args?.where,
    isDeleted: false,
  };
  const data = await this.prisma.product.findMany({ ...args, where });
  const count = await this.prisma.product.count({ where });
  return { count, data, pageSize: args?.take, pages: Math.ceil(count / args?.take) };
}

// Soft delete
async remove(id: string) {
  return this.prisma.product.update({ where: { id }, data: { isDeleted: true } });
}
```

---

## 7. DTO Patterns

```typescript
// create-product.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsNumber, IsPositive } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateProductDto {
  @ApiProperty({ example: 'Laptop' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'A high-end laptop' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ example: 1500 })
  @IsNumber()
  @IsPositive()
  price: number;
}

// update-product.dto.ts — always PartialType
import { PartialType } from '@nestjs/swagger';
export class UpdateProductDto extends PartialType(CreateProductDto) {}

// response DTO — document every field
export class ProductResponseDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() price: number;
  @ApiProperty() createdAt: Date;
  @ApiProperty() updatedAt: Date;
}
```

**Rules:**
- Required body fields: specific validator + `@IsNotEmpty()` + `@ApiProperty()`
- Optional fields: `@IsOptional()` + `@ApiPropertyOptional()`
- Numbers from query strings: `@Type(() => Number)` from class-transformer
- `UpdateDto` always `PartialType(CreateDto)` from `@nestjs/swagger`

---

## 8. Module Declaration

```typescript
@Module({
  controllers: [ProductsController],
  providers: [ProductsService],
  exports: [ProductsService],  // only if another module imports and uses it
})
export class ProductsModule {}
```

Register in `src/app.module.ts`:
```typescript
imports: [ProductsModule, ...]
```

---

## 9. Error Handling

```typescript
throw new NotFoundException(`Record with ID ${id} not found`);
throw new BadRequestException('Validation error message');
throw new ConflictException('Record already exists');
throw new ForbiddenException('Access denied');
```

- Always validate existence before update/delete using `findOne(id)` first
- Wrap risky operations in try-catch, re-throw typed exceptions
- Let `PrismaClientExceptionFilter` (registered globally) handle DB constraint violations

---

## 10. Swagger Documentation Requirements

Every endpoint must have:
- `@ApiTags('resource')` on the class
- `@ApiBearerAuth()` on the class (when protected)
- `@ApiOperation({ summary: '...' })` on every method
- `@ApiResponse({ status: ..., type/description: ... })` on every method — document both success AND error cases
- `@ApiParam({ name: 'id', type: 'string', format: 'uuid' })` for path params
- `@ApiProperty()` / `@ApiPropertyOptional()` on all DTO fields

---

## 11. CommonService Utilities

`CommonService` is global — inject without importing its module:

```typescript
constructor(
  private readonly prisma: PrismaService,
  private readonly commonService: CommonService,
) {}

// Usage
const lotNumber = this.commonService.createLotNumber('PRD');   // 'PRD-XXXX' unique ID
const hash = await this.commonService.hashPassword(password);  // bcrypt salt 12
const otp = this.commonService.genOtp();                       // 4-digit string
const phone = this.commonService.parseIraqiPhoneNumber(raw);
```

---

## 12. Getting Current User

**In controllers**: use the `@User()` decorator and pass to service:
```typescript
async create(@Body() dto: CreateDto, @User() user: UserDto) {
  return this.service.create(dto, user);
}
```

**In admin services** (when `UserProvider` is used): call directly in service:
```typescript
import { UserProvider } from 'src/common/providers/user.provider';
const user = UserProvider.getUser();
```

---

## 13. Status-Change Endpoints (Action Methods)

For action endpoints like `confirm`, `send`, `reject`, `cancel` — the service method uses **arrow function syntax** (not a regular method), matching the bookings module pattern:

```typescript
// Controller
@Post(':id/send')
@ApiOperation({ summary: 'Mark invoice as sent' })
@ApiParam({ name: 'id', type: 'string', format: 'cuid' })
@ApiResponse({ status: HttpStatus.OK, type: InvoiceResponseDto })
@ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Invoice not found' })
@ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Invoice already sent' })
async sendInvoice(@Param('id') id: string, @User() user: UserDto): Promise<Partial<InvoiceResponseDto>> {
  return this.service.sendInvoice(id, user);
}

// Service — arrow function syntax for status transitions
sendInvoice = async (id: string, user: UserDto): Promise<Partial<InvoiceResponseDto>> => {
  const invoice = await this.prisma.invoice.findUnique({ where: { id } });
  if (!invoice) throw new NotFoundException(`Invoice with ID ${id} not found`);
  if (invoice.status === InvoiceStatus.SENT) throw new BadRequestException('Invoice already sent');

  const updated = await this.prisma.invoice.update({
    where: { id },
    data: { status: InvoiceStatus.SENT },
  });

  await this.prisma.log.create({
    data: {
      action: 'UPDATE',        // LogAction only has CREATE | UPDATE | DELETE
      entityName: 'Invoice',
      entityId: id,
      oldData: { status: invoice.status },   // scope to changed fields only
      newData: { status: InvoiceStatus.SENT },
      userId: user.id,
    },
  });

  return updated;
};
```

**Rules:**
- No try/catch on status transitions — let exceptions propagate naturally (unlike `create`/`update`)
- Guard order: `findUnique` → `NotFoundException` → state-check `BadRequestException` → update → audit log
- Map any status transition to `LogAction.UPDATE`

---

---

## 14. Route Ordering (CRITICAL)

NestJS matches routes in definition order. **Specific paths MUST come before parameterized paths**, or the specific path will match as a parameter value.

```typescript
// ✅ CORRECT ORDER
@Controller('units')
export class UnitsController {
  @Get('stats')      // Matches /units/stats
  getStats() { ... }

  @Get('summary')    // Matches /units/summary
  getSummary() { ... }

  @Get(':id')        // Matches /units/abc-123
  getById(@Param('id') id: string) { ... }
}

// ❌ WRONG ORDER — /units/stats matches as id='stats', returns 404
@Controller('units')
export class UnitsController {
  @Get(':id')        // This catches EVERYTHING including 'stats'
  getById(@Param('id') id: string) { ... }

  @Get('stats')      // Never reached!
  getStats() { ... }
}
```

**Rule**: Always define routes in this order:
1. Static paths (`stats`, `summary`, `export`, `me`)
2. Nested static paths (`billing/summary`, `gate/passes`)
3. Parameterized paths (`:id`, `:userId`)
4. Catch-all/wildcard paths last

---

## 15. API Response Field Mapping

When Prisma models use different field names than frontend expects, **always map in the service layer**:

```typescript
// Frontend TypeScript expects:
interface Bill {
  resident: { id: string; name: string };
  status: 'pending' | 'paid';
}

// Prisma returns:
// { user: { id, name }, status: 'PENDING' }

// Service MUST map:
async getBills() {
  const bills = await this.prisma.bill.findMany({
    include: { user: { select: { id: true, name: true } } }
  });
  
  return bills.map(b => ({
    ...b,
    resident: b.user,                    // Rename user → resident
    status: b.status.toLowerCase(),      // PENDING → pending
  }));
}
```

**Common mappings to watch for:**
- `user` → `resident` (property management apps)
- `user` → `customer` (e-commerce apps)
- `assignments` → `residents` (flatten nested relations)
- `notes` → `adminNotes` (field renames)

---

## 16. Pagination Helper

Create a reusable `paginate()` helper and use it for ALL list endpoints:

```typescript
// src/common/utils/paginate.ts
export function paginate<T>(data: T[], total: number, skip: number, take: number) {
  return {
    data,
    total,
    count: data.length,
    page: Math.floor(skip / take) + 1,
    limit: take,
    totalPages: Math.ceil(total / take),
  };
}

// Usage in service:
async getAll(skip = 0, take = 50) {
  const [data, count] = await Promise.all([
    this.prisma.item.findMany({ skip, take, orderBy: { createdAt: 'desc' } }),
    this.prisma.item.count(),
  ]);
  return paginate(data, count, skip, take);
}
```

**Never return raw arrays from list endpoints.** Frontend expects consistent pagination metadata.

---

## Reference Files

- [patterns.md](references/patterns.md) — Complex patterns: transactions, relations, pagination with filters, Prisma schema conventions, test setup
