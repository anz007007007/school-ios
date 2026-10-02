import Foundation

#if !DEBUG
/// В релизной сборке `print` ничего не выводит: в логах устройства (sysdiagnose,
/// Console.app, MDM) оказывались push-токены, тексты уведомлений об оценках и
/// ответы сервера. Функция модуля перекрывает `Swift.print` во всём приложении,
/// поэтому отладочные `print` можно оставлять — в релиз они не попадут.
@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif
