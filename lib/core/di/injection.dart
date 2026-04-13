import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/printing/printer_service.dart';
import 'package:pos_terminal/core/theme/theme_cubit.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/features/auth/data/auth_repository.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/pos/data/category_repository.dart';
import 'package:pos_terminal/features/pos/data/customer_repository.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/category/category_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/category/category_event_state.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_event.dart';
import 'package:pos_terminal/features/settings/data/settings_repository.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // External
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // Theme
  getIt.registerSingleton<ThemeCubit>(ThemeCubit(prefs));

  // Printer
  getIt.registerSingleton<PrinterConfigStorage>(
    PrinterConfigStorage(getIt<SharedPreferences>()),
  );
  getIt.registerSingleton<PrinterService>(PrinterService());

  // Auth storage
  getIt.registerSingleton<AuthLocalStorage>(
    AuthLocalStorage(prefs: getIt<SharedPreferences>()),
  );

  // API client — base URL set after login or from stored URL
  final storedUrl =
      getIt<AuthLocalStorage>().getServerUrl() ?? 'https://localhost';
  getIt.registerSingleton<ApiClient>(
    ApiClient(
      baseUrl: storedUrl,
      authStorage: getIt<AuthLocalStorage>(),
      onAuthFailed: () async {
        // Will be connected to AuthBloc after it's created
      },
    ),
  );

  // Repositories
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerSingleton<PosRepository>(
    PosRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerSingleton<CustomerRepository>(
    CustomerRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerSingleton<CategoryRepository>(
    CategoryRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerSingleton<SettingsRepository>(
    SettingsRepository(apiClient: getIt<ApiClient>()),
  );

  // BLoCs
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: getIt<AuthRepository>(),
      authStorage: getIt<AuthLocalStorage>(),
      apiClient: getIt<ApiClient>(),
    ),
  );

  // Singleton BLoCs — survive across navigation
  getIt.registerLazySingleton<CategoryBloc>(
    () =>
        CategoryBloc(categoryRepository: getIt<CategoryRepository>())
          ..add(const CategoriesLoadRequested()),
  );

  getIt.registerLazySingleton<ProductBloc>(() {
    final authStorage = getIt<AuthLocalStorage>();
    final warehouseId = authStorage.getWarehouseId() ?? 1;
    return ProductBloc(
      posRepository: getIt<PosRepository>(),
      warehouseId: warehouseId,
    )..add(const ProductsLoadRequested());
  });
}
