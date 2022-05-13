#!/bin/bash
clear
pwd
echo $0

echo "-------------------"
###############order###############
order(){
	echo "order().." $1 $2 $3
	order_form=$(yad --width 300 --title "Order Form" --form --button=Agree --button=Cancel --field="product:RO" --field="quantity:CB" --field="price:RO" --field="I accepted order confirmation..:CHK" "$1" "$2" "$3" FALSE) order_result=$?
	echo $order_form
	if ((order_result == 0)); then
		echo "order agree.."
		accept=$(echo $order_form | awk 'BEGIN {FS="|"} {print $4}')
		echo $accept
		if [ $accept = 'TRUE' ]; then
			echo $order_form

			user=$(curl -s "http://192.168.216.1:8090/semiproject/json_sessionId.do")
			quan=$(echo $order_form | awk 'BEGIN {FS="|"} {print $2}')
			comfirm=$(yad --width 300 --height 250 --title "Order" --text="Thank you $user!\nIt's Ordered!\nProduct: $1  Price: $3  Quantity: $quan\ntotal : $((quan * $3)) won\npayment completed!!" --text-align=center --button=OK) confirm_result=$?
			if ((confirm_result == 0)); then
				selectAll
			fi
		else
			echo "check accept false.."
			check_accept=$(yad --width 300 --title "check please.." --text="check your accept.." --text-align=center --button=OK) check_accept_result=$?
			if ((check_accept_result == 0)); then
				cart
			fi

		fi
			
	else
		echo "order cancel.."
		cart

	fi

}


############not_in_stock###########

not_in_stock(){
	not_in_stock=$(yad --width 300 --title "Sorry.." --text="The $product is Out of Stock.." --text-align=center --button=OK) not_in_stock_result=$?
	if ((not_in_stock_result == 0)); then
		selectAll
	fi

}


###############search################
search(){
	echo "search()..."
	search_form=$(yad --width 200 --title "Search" --form --field "SEARCH PRODUCT: ") search_result=$?
	echo $search_form
	if ((search_result == 0)); then
		echo "search OK.."
		product=$(echo $search_form | awk 'BEGIN {FS="|"} {print $1}')
		selectAll $product
	else
		echo "search Cancel.."
		selectAll
	fi

}

###############cart###################
cart(){
	echo "cart()..." $1 $2 $3
	####if all stock in cart ####
	if ((${#3} != 0)); then
		echo "cart quantity" $3
		cart_quant=$(sqlite3 sh31cart.db "select quantity from cart where product='$1'")
		echo $cart_quant
		if [ $3 = $cart_quant ]; then
			echo "equal.."
			not_in_stock
		fi
	fi
	
		echo "cart insert.."
		sqlite3 sh31cart.db "create table if not exists cart(product text unique not null, quantity integer, price integer)"
		sqlite3 sh31cart.db ".databases"
		sqlite3 sh31cart.db ".tables"
	
		if ((${#1} > 0));then
			sqlite3 sh31cart.db "insert into cart(product, quantity, price) values('$1', 1, $2) ON CONFLICT(product) DO UPDATE SET quantity = quantity + 1"
		fi

		cart_sql=$(sqlite3 sh31cart.db "select * from cart")
		list_cart=$(echo $cart_sql)
		IFS="| " read -ra cart_rows <<< $list_cart

		cart_list=$(yad --width 200 --height 500 --title "Cart" --image=sh31mall.jpeg --text="<span color='Red' font='San Bold 20'>Cart</span>" --list --button=Order --button=Back --button=Delete --button="-1":4 --column=PRODUCT --column=QUNATITY --column=PRICE "${cart_rows[@]}") cart_result=$?
	
		product=$(echo $cart_list | awk 'BEGIN {FS="|"} {print $1}')
		quantity=$(echo $cart_list | awk 'BEGIN {FS="|"} {print $2}')
		price=$(echo $cart_list | awk 'BEGIN {FS="|"} {print $3}')
		echo $product $quantity

		#########cart_result################
		if ((cart_result == 0)); then
			echo "Order..."
			quan=""
			for i in $(seq $quantity)
			do
				#echo "i.." $i $quantity
				quan+="$i"
				until [ $i = $quantity ]
				do
					#echo "!.." $i $quantity
					quan+="!"
					break
				done
			done
			echo $quan

			#############order###########
			order $product $quan $price

		elif ((cart_result == 1)); then
			echo "cart Back.."
			selectAll
		elif ((cart_result == 2)); then
			echo "Delete.."
			sqlite3 sh31cart.db "delete from cart where product='$product'"
			cart
		elif ((cart_result == 4)); then
			product=$(echo $cart_list | awk 'BEGIN {FS="|"} {print $1}')
			quantity=$(echo $cart_list | awk 'BEGIN {FS="|"} {print $2}')
			echo "-1..." $product $quantity
			if ((quantity == 1)); then
				sqlite3 sh31cart.db "delete from cart where product='$product'"
				cart
			else
				sqlite3 sh31cart.db "update cart set quantity = (quantity-1) where product='$product'"
				cart
			fi
		fi
	#fi
}

###############more###################
more(){
	echo "more" $1 $2 $3 $4 $5
	
	more_form=$(yad --width 570 --height 250 --title "More Details" --form --image=$5 --button="cart" --button="cancel" --text="<span color='Black' font='Sans 20'>PRODUCT: $1</span> \n<span color='Black' font='Sans 13'>PRICE: $2 won</span> \n<span color='Black' font='Sans 13'>QUANTITY: $3</span> \n<span color='Black' font='Sans 13'>RELEASE DATE: $4</span>") more_result=$?
	
	if ((more_result == 0)); then
		echo "cart.."
		if (($3 > 0)); then
			cart $1 $2 $3
		else
			not_in_stock
		fi
	else
		selectAll
	fi

}

#############selectAll##################

selectAll(){
	echo "selectAll.." $1
	echo ${#1}
	shop_txt=""

	if ((${#1} == 0)); then
		shop_txt=$(echo $(curl -s "http://192.168.216.1:8090/semiproject/json_selectAll.do"|jq '.'))
	else
		shop_txt=$(echo $(curl -s "http://192.168.216.1:8090/semiproject/json_productCheck.do?product=$1"|jq '.'))
	fi

cat > sh31temp.json << END
$shop_txt
END
	#cat sh31temp.json
	board_length=$(jq length sh31temp.json)
	#echo "board_length: "$board_length
	#echo "-----------------"
	
	shop_rows=()
	for i in $(seq 0 $((board_length - 1)))	
	do 
		#echo $i
		product=$(jq -r ".[$i].product" sh31temp.json)
		#echo $product
		price=$(jq -r ".[$i].price" sh31temp.json)
		#echo $price
		quantity=$(jq -r ".[$i].quantity" sh31temp.json)
		#echo $quantity
		release_date=$(jq -r ".[$i].release_date" sh31temp.json)
		#echo $release_date
		file_name=$(jq -r ".[$i].file_name" sh31temp.json)
		#echo $file_name
		shop_rows+=($product $price $quantity $release_date $file_name )
	done

	echo ${shop_rows[@]}

	user=$(curl -s "http://192.168.216.1:8090/semiproject/json_sessionId.do")
	echo "user: "$user

	shop_list=$(yad --width 500 --height 600 --title "ShoppingList" --list --image=sh31mall.jpeg --text="<span color='Red' font='Sans 20'>Hello $user \\(^^)/\nWelcome to IoT Mall !!</span>" --button=More --button=Search --button=Cart --column=PRODUCT --column=PRICE --column=QUANTITY --column=RELEASEDATE --column=FILENAME "${shop_rows[@]}") shop_result=$?
	product=$(echo $shop_list | awk 'BEGIN {FS="|"} {print $1}')
	price=$(echo $shop_list | awk 'BEGIN {FS="|"} {print $2}')
	quantity=$(echo $shop_list | awk 'BEGIN {FS="|"} {print $3}')
	release_date=$(echo $shop_list | awk 'BEGIN {FS="|"} {print $4}')
	file_name=$(echo $shop_list | awk 'BEGIN {FS="|"} {print $5}')

	if ((shop_result == 0)); then
		echo "more.."
		more $product $price $quantity $release_date $file_name
	elif ((shop_result == 1)); then
		echo "search.."
		search
	elif ((shop_result == 2)); then
		echo "cart.."	
		if (($quantity > 0)); then
			cart $product $price $quantity
		else	
			not_in_stock
		fi
	fi

}

#selectAll

############login#################

login(){
	login_form=$(yad --width 200 --title "Login" --form --field "ID" --field "PW:H" "user2" "hi123456") login_result=$?
	if ((login_result == 0)); then
		echo "login successed.."
		echo "login_form: "$login_form
		id=$(echo $login_form | awk 'BEGIN {FS="|"} {print $1}')
		echo $id
		pw=$(echo $login_form | awk 'BEGIN {FS="|"} {print $2}')
		json_id=$(curl -s "http://192.168.216.1:8090/semiproject/json_login.do?id=$id&pw=$pw" |jq -r ".id")
		json_pw=$(curl -s "http://192.168.216.1:8090/semiproject/json_login.do?id=$id&pw=$pw" |jq -r ".pw")
		echo $json_id $json_pw

		if [ $id = $json_id ] && [ $pw = $json_pw ]; then
			echo "login sucessed.."
			curl -s "http://192.168.216.1:8090/semiproject/shlogin.do?id=$id"
			selectAll
		else
			echo "login failed.."
			alert=$(yad --width 300 --title "Login Failed!" --text="Check your password!" --text-align=center) result=$?

		fi
	else
		echo "login canceled.."
	
	fi

}

login


exit 0

