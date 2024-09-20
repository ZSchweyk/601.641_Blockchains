class Test:
	def __init__(self, a: int, b: int) -> None:
		self.a = a
		self.b = b
	def __eq__(self, value: object) -> bool:
		if isinstance(value, Test) and self.a == value.a and self.b == value.b:
			return True
		return False



if __name__ == "__main__":
	o1 = Test(1, 1)
	o1.a = 2
	o2 = Test(1, 2)

	tests = [Test(i, i) for i in range(10)] + [o1]

	print(o1 in tests)