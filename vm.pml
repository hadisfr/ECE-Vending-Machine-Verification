mtype:product_t = { sprite, cocacola }
mtype:req_t = { req_cancel, req_sprite, req_cocacola }
mtype:price_t = { price_sprite, price_cocacola }
mtype:payment_res_t = { payment_success, payment_failure }
mtype:payment_cmd_t = { payment_commit, payment_cancel }

chan req_c = [0] of { mtype:req_t }
chan delivery_c = [0] of { mtype:product_t }
chan price_c = [1] of { mtype:price_t }
chan payment_res_vm_c = [1] of { mtype:payment_res_t }
chan payment_res_agent_c = [0] of { mtype:payment_res_t }
chan payment_cmd_c = [0] of { mtype:payment_cmd_t }

mtype:product_t requested_product, received_product
mtype:price_t payed_price

active proctype VendingMachine() {
    mtype:req_t req
    mtype:payment_res_t payment_res
    mtype:product_t product
end_vm:
    do
        ::
            req_c ? req
            if
                :: req == req_sprite ->
                    atomic {
                        requested_product = sprite
                        product = sprite
                        // payed_price = 0
                        received_product = 0
                        price_c ! price_sprite
                    }
                :: req == req_cocacola ->
                    atomic {
                        requested_product = cocacola
                        product = cocacola
                        // payed_price = 0
                        received_product = 0
                        price_c ! price_cocacola
                    }
            fi
            if
                :: payment_res_vm_c ? payment_success ->
                    delivery_c ! product
                :: req_c ? req_cancel
                //    delivery_c ! 0
            fi
            /*payment_res_vm_c ? payment_res
            if
                :: payment_res == payment_success ->
                    delivery_c ! product
                :: payment_res == payment_failure ->
                    delivery_c ! 0
            fi*/
    od
}

active proctype Atm() {
    mtype:price_t price
    mtype:payment_cmd_t payment_cmd
end_atm:
    do
        ::
            price_c ? price
            do
                ::
                    payment_cmd_c ? payment_cmd
                    if
                        :: payment_cmd == payment_commit ->
                            if
                                :: atomic {
                                    payed_price = price
                                    payment_res_agent_c ! payment_success
                                }
                                    payment_res_vm_c ! payment_success
                                    break
                                :: atomic {
                                    payed_price = 0
                                    payment_res_agent_c ! payment_failure
                                    // payment_res_vm_c ! payment_failure
                                }
                            fi
                        :: payment_cmd == payment_cancel ->
                            atomic {
                                payed_price = 0
                                payment_res_agent_c ! payment_failure
                                // payment_res_vm_c ! payment_failure
                            }
                            break
                    fi
            od
    od
}

active proctype Agent() {
    mtype:product_t product
end_agent:
    do
        ::
            if
                :: req_c ! req_sprite
                :: req_c ! req_cocacola
                :: timeout ->
                    goto end_agent
            fi
            /*atomic {
                payed_price = 0
                received_product = 0
                requested_product = 0
            }*/
            do
                ::
                    if
                        :: payment_cmd_c ! payment_commit ->
                            if
                                :: payment_res_agent_c ? payment_failure
                                :: payment_res_agent_c ? payment_success ->
                                    atomic {
                                        delivery_c ? product
                                        received_product = product
                                    }
                                    break
                            fi
                        :: payment_cmd_c ! payment_cancel ->
                            payment_res_agent_c ? payment_failure
                            break
                        :: req_c ! req_cancel ->
                            break
                    fi
            od
        :: req_c ! req_cancel
        :: payment_cmd_c ! payment_cancel ->
            payment_res_agent_c ? payment_failure
    od
}

/*
ltl receive_product_which_was_requested { [](received_product != 0 -> received_product == requested_product) }
ltl receive_product_after_pay { [](((payed_price == 0) && X(payed_price != 0)) -> X(<> (received_product != 0))) }
ltl correct_price { [](received_product != 0 -> (
        (received_product == sprite -> payed_price == price_sprite)
        &&
        (received_product == cocacola -> payed_price == price_cocacola)
    )) }
*/
