class_name CommandPayment
extends RefCounted
## 入队时收据：只记实际付款者和金额；完成或取消最多结算一次。
var _payer: WeakRef
var _amount := 0.0
var _settled := false

static func charge(payer: ElixirManager, amount: float) -> CommandPayment:
	if not is_finite(amount) or amount < 0.0:
		return null
	if amount > 0.0 and (payer == null or not payer.spend(amount)):
		return null
	var payment := CommandPayment.new()
	payment._payer = weakref(payer) if payer != null else null
	payment._amount = amount
	return payment

func settle(refund: bool) -> void:
	if _settled:
		return
	_settled = true
	if not refund or _payer == null:
		return
	var payer = _payer.get_ref()
	if is_instance_valid(payer):
		# ElixirManager 的 setter 统一执行上限并通知 UI；不能按取消时的技能费用重算。
		payer.elixir += _amount

func is_settled() -> bool:
	return _settled
